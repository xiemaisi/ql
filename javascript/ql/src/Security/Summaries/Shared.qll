/**
 * Imports the standard library and all taint-tracking configuration classes from the security queries.
 */

import javascript

private import semmle.javascript.security.dataflow.ClientSideUrlRedirect
private import semmle.javascript.security.dataflow.CodeInjection
private import semmle.javascript.security.dataflow.CommandInjection
private import semmle.javascript.security.dataflow.DomBasedXss as DomBasedXss
private import semmle.javascript.security.dataflow.NosqlInjection
private import semmle.javascript.security.dataflow.ReflectedXss as ReflectedXss
private import semmle.javascript.security.dataflow.RegExpInjection
private import semmle.javascript.security.dataflow.ServerSideUrlRedirect
private import semmle.javascript.security.dataflow.SqlInjection
private import semmle.javascript.security.dataflow.StackTraceExposure
private import semmle.javascript.security.dataflow.TaintedFormatString
private import semmle.javascript.security.dataflow.TaintedPath
private import semmle.javascript.security.dataflow.TypeConfusionThroughParameterTampering
private import semmle.javascript.security.dataflow.UnsafeDeserialization
private import semmle.javascript.security.dataflow.XmlBomb
private import semmle.javascript.security.dataflow.XpathInjection
private import semmle.javascript.security.dataflow.Xxe

class SourceNodeWithSomeCopiedProperties extends DataFlow::SourceNode {
  SourceNodeWithSomeCopiedProperties() {
    exists(dynamicPropRef(this, _))
  }

  override DataFlow::InvokeNode getAMemberInvocation(string memberName) {
    result = super.getAMemberInvocation(memberName)
    or
    exists (DataFlow::SourceNode that |
      copyProperty(that, memberName, this) and
      result = that.getAMemberInvocation(memberName)
    )
  }
}

class SourceNodeWithCopiedProperties extends DataFlow::SourceNode {
  SourceNodeWithCopiedProperties() {
    exists(dynamicPropRef(this, _))
  }

  override DataFlow::InvokeNode getAMemberInvocation(string memberName) {
    result = super.getAMemberInvocation(memberName)
    or
    exists (DataFlow::SourceNode that |
      copyAllProperties(that, this) and
      result = that.getAMemberInvocation(memberName)
    )
  }
}

private predicate iteratesOver(EnhancedForLoop efl, SsaVariable var, DataFlow::SourceNode domain) {
  domain.flowsToExpr(efl.getIterationDomain()) and
  var.getDefinition().(SsaExplicitDefinition).getDef() = efl.getIteratorExpr()
}

private predicate iteratesOverValuesOf(SsaVariable var, DataFlow::SourceNode iter) {
  exists (string m | m = "forEach" or m = "map" |
    iter.getAMethodCall(m).getCallback(0).getParameter(0) = DataFlow::ssaDefinitionNode(var)
  )
  or
  exists (EnhancedForLoop fos | fos instanceof ForOfStmt or fos instanceof ForEachStmt |
    iteratesOver(fos, var, iter)
  )
}

private predicate iteratesOverKeysOf(SsaVariable var, DataFlow::SourceNode iter) {
  exists (string m | m = "forEach" or m = "map" |
    iter.getAMethodCall(m).getCallback(0).getParameter(1) = DataFlow::ssaDefinitionNode(var)
  )
  or
  exists (ForInStmt fis |
    iteratesOver(fis, var, iter)
  )
}

private DataFlow::PropRef dynamicPropRef(DataFlow::SourceNode base, SsaVariable indexVar) {
  base.flowsTo(result.getBase()) and
  result.getPropertyNameExpr() = indexVar.getAUse()
}

private predicate propCopy(DataFlow::SourceNode targetBase, SsaVariable indexVar, DataFlow::SourceNode sourceBase) {
  exists (DataFlow::PropWrite pw, DataFlow::PropRead pr |
    pw = dynamicPropRef(targetBase, indexVar) and
    pr = dynamicPropRef(sourceBase, indexVar) and
    pr.flowsTo(pw.getRhs()) and
    targetBase != sourceBase
  )
}

private predicate localFunctionCall(DataFlow::InvokeNode invk, DataFlow::FunctionNode fn) {
  fn.flowsTo(invk.getCalleeNode())
}

private predicate copyProperty(DataFlow::SourceNode targetBase, string prop, DataFlow::SourceNode sourceBase) {
  exists (SsaVariable propVar, DataFlow::ArrayLiteralNode arr |
    iteratesOverValuesOf(propVar, arr) and
    arr.getAnElement().mayHaveStringValue(prop) and
    propCopy(targetBase, propVar, sourceBase)
  )
  or
  exists (DataFlow::FunctionNode fn, int i, DataFlow::InvokeNode invk |
    copyProperty(fn.getParameter(i), prop, sourceBase) and
    localFunctionCall(invk, fn) and
    targetBase.flowsTo(invk.getArgument(i))
  )
}

private predicate copyAllProperties(DataFlow::SourceNode targetBase, DataFlow::SourceNode sourceBase) {
  exists (SsaVariable propVar |
    iteratesOverKeysOf(propVar, sourceBase) and
    propCopy(targetBase, propVar, sourceBase)
  )
  or
  exists (DataFlow::FunctionNode fn, int i, DataFlow::InvokeNode invk |
    copyAllProperties(fn.getParameter(i), sourceBase) and
    localFunctionCall(invk, fn) and
    targetBase.flowsTo(invk.getArgument(i))
  )
}
