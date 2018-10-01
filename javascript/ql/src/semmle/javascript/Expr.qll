/**
 * Provides classes for working with expressions.
 */

import javascript

/** A program element that is either an expression or a type annotation. */
class ExprOrType extends @exprortype, Documentable {
  /** Gets the statement in which this expression or type appears. */
  Stmt getEnclosingStmt() {
    enclosingStmt(this, result)
  }

  /** Gets the function in which this expression or type appears, if any. */
  Function getEnclosingFunction() {
    result = getContainer()
  }

  /**
   * Gets the statement container (function or toplevel) in which
   * this expression or type appears.
   */
  StmtContainer getContainer() {
    exprContainers(this, result)
  }

  /**
   * Gets the JSDoc comment associated with this expression or type or its parent statement, if any.
   */
  override JSDoc getDocumentation() {
    result = getOwnDocumentation() or
    // if there is no JSDoc for the expression itself, check the enclosing property or statement
    (not exists(getOwnDocumentation()) and
     if getParent() instanceof Property then
       result = getParent().(Property).getDocumentation()
     else
       result = getEnclosingStmt().getDocumentation())
  }

  /** Gets a JSDoc comment that is immediately before this expression or type (ignoring parentheses). */
  private JSDoc getOwnDocumentation() {
    exists (Token tk | tk = result.getComment().getNextToken() |
      tk = this.getFirstToken() or
      exists (Expr p | p.stripParens() = this | tk = p.getFirstToken())
    )
  }

  /** Gets this expression or type, with any surrounding parentheses removed. */
  ExprOrType stripParens() { result = this }
}

/** An expression. */
class Expr extends @expr, ExprOrStmt, ExprOrType, AST::ValueNode {
  /**
   * Gets the statement container (function or toplevel) in which
   * this expression appears.
   */
  override StmtContainer getContainer() {
    exprContainers(this, result)
  }

  /** Gets this expression, with any surrounding parentheses removed. */
  override Expr stripParens() {
    result = this
  }

  /** Gets the constant integer value this expression evaluates to, if any. */
  int getIntValue() {
    none()
  }

  /** Gets the constant string value this expression evaluates to, if any. */
  string getStringValue() {
    none()
  }

  /** Holds if this expression is impure, that is, its evaluation could have side effects. */
  predicate isImpure() {
    any()
  }

  /**
   * Holds if this expression is pure, that is, is its evaluation is guaranteed to be
   * side effect-free.
   */
  predicate isPure() {
    not isImpure()
  }

  /**
   * Gets the kind of this expression, which is an integer value representing the expression's
   * node type.
   *
   * _Note_: The mapping from node types to integers is considered an implementation detail
   * and may change between versions of the extractor.
   */
  int getKind() {
     exprs(this, result, _, _, _)
  }

  override string toString() {
    exprs(this, _, _, _, result)
  }

  /**
   * Gets the expression that is the parent of this expression in the AST, if any.
   *
   * Note that for property names and property values the associated object expression or pattern
   * is returned, skipping the property node itself (which is not an expression).
   */
  Expr getParentExpr() {
    this = result.getAChildExpr() or
    exists (Property prop |
      result = prop.getParent() and
      this = prop.getAChildExpr()
    )
  }

  /**
   * Holds if this expression accesses the global variable `g`, either directly
   * or through the `window` object.
   */
  predicate accessesGlobal(string g) {
    flow().accessesGlobal(g)
  }

  /**
   * Holds if this expression may evaluate to `s`.
   */
  predicate mayHaveStringValue(string s) {
    flow().mayHaveStringValue(s)
  }

  /**
   * Holds if this expression may evaluate to `b`.
   */
  predicate mayHaveBooleanValue(boolean b) {
    flow().mayHaveBooleanValue(b)
  }

  /**
   * Holds if this expression may refer to the initial value of parameter `p`.
   */
  predicate mayReferToParameter(Parameter p) {
    flow().mayReferToParameter(p)
  }

  /**
   * Gets the static type of this expression, as determined by the TypeScript type system.
   *
   * Has no result if the expression is in a JavaScript file or in a TypeScript
   * file that was extracted without type information.
   */
  Type getType() {
    ast_node_type(this, result)
  }
}

/** An identifier. */
class Identifier extends @identifier, ExprOrType {
  /** Gets the name of this identifier. */
  string getName() {
    literals(result, _, this)
  }
}

/**
 * A statement or property label, that is, an identifier that
 * does not refer to a variable.
 */
class Label extends @label, Identifier, Expr {
  override predicate isImpure() { none() }
}

/** A literal. */
class Literal extends @literal, Expr {
  /** Gets the value of this literal, as a string. */
  string getValue() {
    literals(result, _, this)
  }

  /**
   * Gets the raw source text of this literal, including quotes for
   * string literals.
   */
  string getRawValue() {
    literals(_, result, this)
  }

  override predicate isImpure() {
    none()
  }
}

/** A parenthesized expression. */
class ParExpr extends @parexpr, Expr {
  /** Gets the expression within parentheses. */
  Expr getExpression() {
    result = this.getChildExpr(0)
  }

  override Expr stripParens() {
    result = getExpression().stripParens()
  }

  override int getIntValue() {
    result = getExpression().getIntValue()
  }

  override predicate isImpure() {
    getExpression().isImpure()
  }
}

/** A `null` literal. */
class NullLiteral extends @nullliteral, Literal {}

/** A Boolean literal, that is, either `true` or `false`. */
class BooleanLiteral extends @booleanliteral, Literal {}

/** A numeric literal. */
class NumberLiteral extends @numberliteral, Literal {
  /** Gets the integer value of this literal. */
  override int getIntValue() {
    result = getValue().toInt()
  }

  /** Gets the floating point value of this literal. */
  float getFloatValue() {
    result = getValue().toFloat()
  }
}

/** A bigint literal. */
class BigIntLiteral extends @bigintliteral, Literal {
  /**
   * Gets the integer value of this literal if it can be represented
   * as a QL integer value.
   */
  override int getIntValue() {
    result = getValue().toInt()
  }

  /**
   * Gets the floating point value of this literal if it can be represented
   * as a QL floating point value.
   */
  float getFloatValue() {
    result = getValue().toFloat()
  }
}

/** A string literal. */
class StringLiteral extends @stringliteral, Literal {
  override string getStringValue() {
    result = getValue()
  }
}

/** A regular expression literal. */
class RegExpLiteral extends @regexpliteral, Literal, RegExpParent {
  /** Gets the root term of this regular expression literal. */
  RegExpTerm getRoot() {
    this = result.getParent()
  }

  /** Gets the flags of this regular expression. */
  string getFlags() {
    result = getValue().regexpCapture(".*/(\\w*)$", 1)
  }

  /** Holds if this regular expression has an `m` flag. */
  predicate isMultiline() {
    getFlags().matches("%m%")
  }

  /** Holds if this regular expression has a `g` flag. */
  predicate isGlobal() {
    getFlags().matches("%g%")
  }

  /** Holds if this regular expression has an `i` flag. */
  predicate isIgnoreCase() {
    getFlags().matches("%i%")
  }

  /** Holds if this regular expression has an `s` flag. */
  predicate isDotAll() {
    getFlags().matches("%s%")
  }
}

/** A `this` expression. */
class ThisExpr extends @thisexpr, Expr {
  override predicate isImpure() {
    none()
  }

  /**
   * Gets the function whose `this` binding this expression refers to,
   * which is the nearest enclosing non-arrow function.
   */
  Function getBinder() {
    result = getEnclosingFunction().getThisBinder()
  }
}

/** An array literal. */
class ArrayExpr extends @arrayexpr, Expr {
  /** Gets the `i`th element of this array literal. */
  Expr getElement(int i) {
    result = this.getChildExpr(i)
  }

  /** Gets an element of this array literal. */
  Expr getAnElement() {
    result = this.getAChildExpr()
  }

  /** Gets the number of elements in this array literal. */
  int getSize() {
    arraySize(this, result)
  }

  /**
   * Holds if this array literal includes a trailing comma after the
   * last element.
   */
  predicate hasTrailingComma() {
    this.getLastToken().getPreviousToken().getValue() = ","
  }

  /** Holds if the `i`th element of this array literal is omitted. */
  predicate elementIsOmitted(int i) {
    i in [0..getSize()-1] and
    not exists (getElement(i))
  }

  /** Holds if this array literal has an omitted element. */
  predicate hasOmittedElement() {
    elementIsOmitted(_)
  }

  override predicate isImpure() {
    getAnElement().isImpure()
  }
}

/** An object literal. */
class ObjectExpr extends @objexpr, Expr {
  /** Gets the `i`th property in this object literal. */
  Property getProperty(int i) {
    properties(result, this, i, _, _)
  }

  /** Gets a property in this object literal. */
  Property getAProperty() {
    exists (int i | result = this.getProperty(i))
  }

  /** Gets the number of properties in this object literal. */
  int getNumProperty() {
    result = count(this.getAProperty())
  }

  /** Gets the property with the given name, if any. */
  Property getPropertyByName(string name) {
    result = this.getAProperty() and
    result.getName() = name
  }

  /**
   * Holds if this object literal includes a trailing comma after the
   * last property.
   */
  predicate hasTrailingComma() {
    this.getLastToken().getPreviousToken().getValue() = ","
  }

  override predicate isImpure() {
    getAProperty().isImpure()
  }
}

/**
 * A property definition in an object literal, which may be either
 * a value property, a property getter, or a property setter.
 */
class Property extends @property, Documentable {
  Property() {
    // filter out property patterns and JSX attributes
    exists (ObjectExpr obj | properties(this, obj, _, _, _))
  }

  /**
   * Gets the expression specifying the name of this property.
   *
   * For normal properties, this is either an identifier, a string literal, or a
   * numeric literal; for computed properties it can be an arbitrary expression;
   * for spread properties, it is not defined.
   */
  Expr getNameExpr() {
    result = this.getChildExpr(0)
  }

  /** Gets the expression specifying the initial value of this property. */
  Expr getInit() {
    result = this.getChildExpr(1)
  }

  /** Gets the name of this property. */
  string getName() {
    not isComputed() and result = getNameExpr().(Identifier).getName() or
    result = getNameExpr().(Literal).getValue()
  }

  /** Holds if the name of this property is computed. */
  predicate isComputed() {
    isComputed(this)
  }

  /** Holds if this property is defined using method syntax. */
  predicate isMethod() {
    isMethod(this)
  }

  /** Holds if this property is defined using shorthand syntax. */
  predicate isShorthand() {
    getNameExpr().getLocation() = getInit().getLocation()
  }

  /** Gets the object literal this property belongs to. */
  ObjectExpr getObjectExpr() {
    properties(this, result, _, _, _)
  }

  /** Gets the (0-based) index at which this property appears in its enclosing literal. */
  int getIndex() {
    this = getObjectExpr().getProperty(result)
  }

  /** Gets the function or toplevel in which this property occurs. */
  StmtContainer getContainer() {
    result = getObjectExpr().getContainer()
  }

  /**
   * Holds if this property is impure, that is, the evaluation of its name or
   * its initializer expression could have side effects.
   */
  predicate isImpure() {
    (isComputed() and getNameExpr().isImpure()) or
    getInit().isImpure()
  }

  override string toString() {
    properties(this, _, _, _, result)
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getNameExpr().getFirstControlFlowNode() or
    not exists(getNameExpr()) and result = getInit().getFirstControlFlowNode()
  }

  /**
   * Gets the kind of this property, which is an opaque integer
   * value indicating whether this property is a value property,
   * a property getter, or a property setter.
   */
  int getKind() {
    properties(this, _, _, result, _)
  }

  /**
   * Gets the `i`th decorator applied to this property.
   *
   * For example, the property `@A @B x: 42` has
   * `@A` as its 0th decorator, and `@B` as its first decorator.
   */
  Decorator getDecorator(int i) {
    result = getChildExpr(-(i+1))
  }

  /**
   * Gets a decorator applied to this property.
   *
   * For example, the property `@A @B x: 42` has
   * decorators `@A` and `@B`.
   */
  Decorator getADecorator() {
    result = getDecorator(_)
  }
}

/** A value property in an object literal. */
class ValueProperty extends Property, @value_property {
}

/** A property getter or setter in an object literal. */
class PropertyAccessor extends Property, @property_accessor {
  override FunctionExpr getInit() {
    result = Property.super.getInit()
  }
}

/** A property getter in an object literal. */
class PropertyGetter extends PropertyAccessor, @property_getter {
}

/** A property setter in an object literal. */
class PropertySetter extends PropertyAccessor, @property_setter {
}

/**
 * A spread property in an object literal, such as `...others` in
 * `{ x: 42, ...others }`. The value of a spread property is always
 * a `SpreadElement`.
 */
class SpreadProperty extends Property {
  SpreadProperty() {
    not exists(getNameExpr())
  }
}

/** A function expression. */
class FunctionExpr extends @functionexpr, Expr, Function {
  /** Gets the name of this function expression, if any. */
  override string getName() {
    result = getId().getName()
  }

  /** Holds if this function expression is a property setter. */
  predicate isSetter() {
    exists (PropertySetter s | s.getInit() = this)
  }

  /** Holds if this function expression is a property getter. */
  predicate isGetter() {
    exists (PropertyGetter g | g.getInit() = this)
  }

  /** Holds if this function expression is a property accessor. */
  predicate isAccessor() {
    exists (PropertyAccessor acc | acc.getInit() = this)
  }

  /** Gets the statement in which this function expression appears. */
  override Stmt getEnclosingStmt() {
    result = Expr.super.getEnclosingStmt()
  }

  override StmtContainer getEnclosingContainer() {
    result = Expr.super.getContainer()
  }

  override predicate isImpure() {
    none()
  }
}

/** An arrow expression. */
class ArrowFunctionExpr extends @arrowfunctionexpr, Expr, Function {
  /** Gets the statement in which this expression appears. */
  override Stmt getEnclosingStmt() {
    result = Expr.super.getEnclosingStmt()
  }

  override StmtContainer getEnclosingContainer() {
    result = Expr.super.getContainer()
  }

  override predicate isImpure() {
    none()
  }

  override Function getThisBinder() {
    result = getEnclosingContainer().(Function).getThisBinder()
  }
}

/** A sequence expression (also known as comma expression). */
class SeqExpr extends @seqexpr, Expr {
  /** Gets the `i`th expression in this sequence. */
  Expr getOperand(int i) {
    result = getChildExpr(i)
  }

  /** Gets an expression in this sequence. */
  Expr getAnOperand() {
    result = getOperand(_)
  }

  /** Gets the number of expressions in this sequence. */
  int getNumOperands() {
    result = count(getOperand(_))
  }

  /** Gets the last expression in this sequence. */
  Expr getLastOperand() {
    result = getOperand(getNumOperands()-1)
  }

  override predicate isImpure() {
    getAnOperand().isImpure()
  }

  override string getStringValue() {
    result = getLastOperand().getStringValue()
  }
}

/** A conditional expression. */
class ConditionalExpr extends @conditionalexpr, Expr {
  /** Gets the condition expression of this conditional. */
  Expr getCondition() {
    result = getChildExpr(0)
  }

  /** Gets the 'then' expression of this conditional. */
  Expr getConsequent() {
    result = getChildExpr(1)
  }

  /** Gets the 'else' expression of this conditional. */
  Expr getAlternate() {
    result = getChildExpr(2)
  }

  /** Gets either the 'then' or the 'else' expression of this conditional. */
  Expr getABranch() {
    result = getConsequent() or result = getAlternate()
  }

  override predicate isImpure() {
    getCondition().isImpure() or
    getABranch().isImpure()
  }
}

/**
 * An invocation expression, that is, either a function call or
 * a `new` expression.
 */
class InvokeExpr extends @invokeexpr, Expr {
  /** Gets the expression specifying the function to be called. */
  Expr getCallee() {
    result = this.getChildExpr(-1)
  }

  /** Gets the name of the function or method being invoked, if it can be determined. */
  string getCalleeName() {
    exists (Expr callee | callee = getCallee().stripParens() |
      result = ((Identifier)callee).getName() or
      result = ((PropAccess)callee).getPropertyName()
    )
  }

  /** Gets the `i`th argument of this invocation. */
  Expr getArgument(int i) {
    i >= 0 and result = this.getChildExpr(i)
  }

  /** Gets an argument of this invocation. */
  Expr getAnArgument() {
    result = getArgument(_)
  }

  /** Gets the last argument of this invocation, if any. */
  Expr getLastArgument() {
    result = getArgument(getNumArgument()-1)
  }

  /** Gets the number of arguments of this invocation. */
  int getNumArgument() {
    result = count(getAnArgument())
  }

  /** Gets the `i`th type argument of this invocation. */
  TypeExpr getTypeArgument(int i) {
    i >= 0 and result = this.getChildTypeExpr(-i - 2)
  }

  /** Gets a type argument of this invocation. */
  TypeExpr getATypeArgument() {
      result = getTypeArgument(_)
  }

  /** Gets the number of type arguments of this invocation. */
  int getNumTypeArgument() {
      result = count(getATypeArgument())
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getCallee().getFirstControlFlowNode()
  }

  /** Holds if the argument list of this function has a trailing comma. */
  predicate hasTrailingComma() {
    // check whether the last token of this invocation is a closing
    // parenthesis, which itself is preceded by a comma
    exists (PunctuatorToken rparen | rparen.getValue() = ")" |
      rparen = getLastToken() and
      rparen.getPreviousToken().getValue() = ","
    )
  }

  /**
   * Holds if the `i`th argument of this invocation is a spread element.
   */
  predicate isSpreadArgument(int i) {
    getArgument(i).stripParens() instanceof SpreadElement
  }

  /**
   * Holds if the `i`th argument of this invocation is an object literal whose property
   * `name` is set to `value`.
   *
   * This predicate is an approximation, computed using only local data flow.
   */
  predicate hasOptionArgument(int i, string name, Expr value) {
    value = flow().(DataFlow::InvokeNode).getOptionArgument(i, name).asExpr()
  }

  /**
   * Gets the call signature of the invoked function, as determined by the TypeScript
   * type system, with overloading resolved and type parameters substituted.
   *
   * This predicate is only populated for files extracted with full TypeScript extraction.
   */
  CallSignatureType getResolvedSignature() {
    invoke_expr_signature(this, result)
  }

  /**
   * Gets the index of the targeted call signature among the overload signatures
   * on the invoked function.
   *
   * This predicate is only populated for files extracted with full TypeScript extraction.
   */
  int getResolvedOverloadIndex() {
    invoke_expr_overload_index(this, result)
  }

  /**
   * Gets the canonical name of the static call target, as determined by the TypeScript type system.
   *
   * This predicate is only populated for files extracted with full TypeScript extraction.
   */
  CanonicalFunctionName getResolvedCalleeName() {
    ast_node_symbol(this, result)
  }

  /**
   * Gets the statically resolved target function, as determined by the TypeScript type system, if any.
   *
   * This predicate is only populated for files extracted with full TypeScript extraction.
   *
   * Note that the resolved function may be overridden in a subclass and thus is not
   * necessarily the actual target of this invocation at runtime. 
   */
  Function getResolvedCallee() {
    result = getResolvedCalleeName().getImplementation()
  }
}

/** A `new` expression. */
class NewExpr extends @newexpr, InvokeExpr {}

/** A function call expression. */
class CallExpr extends @callexpr, InvokeExpr {
  /**
   * Gets the expression specifying the receiver on which the function
   * is invoked, if any.
   */
  Expr getReceiver() {
    result = getCallee().(PropAccess).getBase()
  }
}

/** A method call expression. */
class MethodCallExpr extends CallExpr {
  MethodCallExpr() {
    getCallee().stripParens() instanceof PropAccess
  }

  /**
   * Gets the property access referencing the method to be invoked.
   */
  private PropAccess getMethodRef() {
    result = getCallee().stripParens()
  }

  /**
   * Gets the receiver expression of this method call.
   */
  override Expr getReceiver() {
    result = getMethodRef().getBase()
  }

  /**
   * Gets the name of the invoked method, if it can be determined.
   */
  string getMethodName() {
    result = getMethodRef().getPropertyName()
  }

  /** Holds if this invocation calls method `m` on expression `base`. */
  predicate calls(Expr base, string m) {
    getMethodRef().accesses(base, m)
  }
}

/**
 * A property access, that is, either a dot expression of the form
 * `e.f` or an index expression of the form `e[p]`.
 */
class PropAccess extends @propaccess, Expr {
  /** Gets the base expression on which the property is accessed. */
  Expr getBase() {
    result = getChildExpr(0)
  }

  /**
   * Gets the expression specifying the name of the property being
   * read or written. For dot expressions, this is an identifier; for
   * index expressions it can be an arbitrary expression.
   */
  Expr getPropertyNameExpr() {
    result = getChildExpr(1)
  }

  /** Gets the name of the accessed property, if it can be determined. */
  string getPropertyName() {
    none()
  }

  /** Gets the qualified name of the accessed property, if it can be determined. */
  string getQualifiedName() {
    exists (string basename |
      basename = getBase().(Identifier).getName() or
      basename = getBase().(PropAccess).getQualifiedName() |
      result = basename + "." + getPropertyName()
    )
  }

  /** Holds if this property name accesses property `p` on expression `base`. */
  predicate accesses(Expr base, string p) {
    base = getBase() and
    p = getPropertyName()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getBase().getFirstControlFlowNode()
  }
}

/** A dot expression. */
class DotExpr extends @dotexpr, PropAccess {
  override string getPropertyName() {
    result = getProperty().getName()
  }

  /** Gets the identifier specifying the name of the accessed property. */
  Identifier getProperty() {
   result = getChildExpr(1)
  }

  override predicate isImpure() {
    getBase().isImpure()
  }
}

/** An index expression (also known as computed property access). */
class IndexExpr extends @indexexpr, PropAccess {
  /** Gets the expression specifying the name of the accessed property. */
  Expr getIndex() {
    result = getChildExpr(1)
  }

  override string getPropertyName() {
    result = ((Literal)getIndex()).getValue()
  }

  override predicate isImpure() {
    getBase().isImpure() or
    getIndex().isImpure()
  }
}

/** An expression with a unary operator. */
class UnaryExpr extends @unaryexpr, Expr {
  /** Gets the operand of this unary operator. */
  Expr getOperand() {
    result = getChildExpr(0)
  }

  /** Gets the operator of this expression. */
  string getOperator() {
    none()
  }

  override predicate isImpure() {
    getOperand().isImpure()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getOperand().getFirstControlFlowNode()
  }
}

/** An arithmetic negation expression (also known as unary minus). */
class NegExpr extends @negexpr, UnaryExpr {
  override string getOperator() {
    result = "-"
  }

  override int getIntValue() {
    result = -getOperand().getIntValue()
  }
}

/** A unary plus expression. */
class PlusExpr extends @plusexpr, UnaryExpr {
  override string getOperator() {
    result = "+"
  }
}

/** A logical negation expression. */
class LogNotExpr extends @lognotexpr, UnaryExpr {
  override string getOperator() {
    result = "!"
  }
}

/** A bitwise negation expression. */
class BitNotExpr extends @bitnotexpr, UnaryExpr {
  override string getOperator() {
    result = "~"
  }
}

/** A `typeof` expression. */
class TypeofExpr extends @typeofexpr, UnaryExpr {
  override string getOperator() {
    result = "typeof"
  }
}

/** A `void` expression. */
class VoidExpr extends @voidexpr, UnaryExpr {
  override string getOperator() {
    result = "void"
  }
}

/** A `delete` expression. */
class DeleteExpr extends @deleteexpr, UnaryExpr {
  override string getOperator() {
    result = "delete"
  }

  override predicate isImpure() {
    any()
  }
}

/** A spread element. */
class SpreadElement extends @spreadelement, UnaryExpr {
  override string getOperator() {
    result = "..."
  }
}

/** An expression with a binary operator. */
class BinaryExpr extends @binaryexpr, Expr {
  /** Gets the left operand of this binary operator. */
  Expr getLeftOperand() {
    result = getChildExpr(0)
  }

  /** Gets the right operand of this binary operator. */
  Expr getRightOperand() {
    result = getChildExpr(1)
  }

  /** Gets an operand of this binary operator. */
  Expr getAnOperand() {
    result = getAChildExpr()
  }

  /** Holds if `e` and `f` (in either order) are the two operands of this expression. */
  predicate hasOperands(Expr e, Expr f) {
    e = getAnOperand() and
    f = getAnOperand() and
    e != f
  }

  /** Gets the operator of this expression. */
  string getOperator() {
    none()
  }

  override predicate isImpure() {
    getAnOperand().isImpure()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getLeftOperand().getFirstControlFlowNode()
  }

  /**
   * Gets the number of whitespace characters around the operator of this expression.
   *
   * This predicate is only defined if both operands are on the same line, and if the
   * amount of whitespace before and after the operator are the same.
   */
  int getWhitespaceAroundOperator() {
    exists (Token lastLeft, Token operator, Token firstRight, int l, int c1, int c2, int c3, int c4 |
      lastLeft = getLeftOperand().getLastToken() and
      operator = lastLeft.getNextToken() and
      firstRight = operator.getNextToken() and
      lastLeft.getLocation().hasLocationInfo(_, _, _, l, c1) and
      operator.getLocation().hasLocationInfo(_, l, c2, l, c3) and
      firstRight.getLocation().hasLocationInfo(_, l, c4, _, _) and
      result = c2-c1-1 and
      result = c4-c3-1
    )
  }

  predicate hasLineBreakBetweenOperands() {
    getLeftOperand().getLocation().getEndLine() < getRightOperand().getLocation().getStartLine()
  }
}

/**
 * A comparison expression, that is, either an equality test
 * (`==`, `!=`, `===`, `!==`) or a relational expression
 * (`<`, `<=`, `>=`, `>`).
 */
class Comparison extends @comparison, BinaryExpr {}

/** An equality test using `==`, `!=`, `===` or `!==`. */
class EqualityTest extends @equalitytest, Comparison {
  /** Gets the polarity of this test: `true` for equalities, `false` for inequalities. */
  boolean getPolarity() {
    (this instanceof EqExpr or this instanceof StrictEqExpr) and result = true
    or
    (this instanceof NEqExpr or this instanceof StrictNEqExpr) and result = false
  }
}

/** An equality test using `==`. */
class EqExpr extends @eqexpr, EqualityTest {
  override string getOperator() {
    result = "=="
  }
}

/** An inequality test using `!=`. */
class NEqExpr extends @neqexpr, EqualityTest {
  override string getOperator() {
    result = "!="
  }
}

/** A strict equality test using `===`. */
class StrictEqExpr extends @eqqexpr, EqualityTest {
  override string getOperator() {
    result = "==="
  }
}

/** A strict inequality test using `!==`. */
class StrictNEqExpr extends @neqqexpr, EqualityTest {
  override string getOperator() {
    result = "!=="
  }
}

/** A less-than expression. */
class LTExpr extends @ltexpr, Comparison {
  override string getOperator() {
    result = "<"
  }
}

/** A less-than-or-equal expression. */
class LEExpr extends @leexpr, Comparison {
  override string getOperator() {
    result = "<="
  }
}

/** A greater-than expression. */
class GTExpr extends @gtexpr, Comparison {
  override string getOperator() {
    result = ">"
  }
}

/** A greater-than-or-equal expression. */
class GEExpr extends @geexpr, Comparison {
  override string getOperator() {
    result = ">="
  }
}

/** A left-shift expression using `<<`. */
class LShiftExpr extends @lshiftexpr, BinaryExpr {
  override string getOperator() {
    result = "<<"
  }
}

/** A right-shift expression using `>>`. */
class RShiftExpr extends @rshiftexpr, BinaryExpr {
  override string getOperator() {
    result = ">>"
  }
}

/** An unsigned right-shift expression using `>>>`. */
class URShiftExpr extends @urshiftexpr, BinaryExpr {
  override string getOperator() {
    result = ">>>"
  }
}

/** An addition expression. */
class AddExpr extends @addexpr, BinaryExpr {
  override string getOperator() {
    result = "+"
  }

  override string getStringValue() {
    result = getLeftOperand().getStringValue() + getRightOperand().getStringValue()
  }
}

/** A subtraction expression. */
class SubExpr extends @subexpr, BinaryExpr {
  override string getOperator() {
    result = "-"
  }
}

/** A multiplication expression. */
class MulExpr extends @mulexpr, BinaryExpr {
  override string getOperator() {
    result = "*"
  }
}

/** A division expression. */
class DivExpr extends @divexpr, BinaryExpr {
  override string getOperator() {
    result = "/"
  }
}

/** A modulo expression. */
class ModExpr extends @modexpr, BinaryExpr {
  override string getOperator() {
    result = "%"
  }
}

/** An exponentiation expression. */
class ExpExpr extends @expexpr, BinaryExpr {
  override string getOperator() {
    result = "**"
  }
}

/** A bitwise 'or' expression. */
class BitOrExpr extends @bitorexpr, BinaryExpr {
  override string getOperator() {
    result = "|"
  }
}

/** An exclusive 'or' expression. */
class XOrExpr extends @xorexpr, BinaryExpr {
  override string getOperator() {
    result = "^"
  }
}

/** A bitwise 'and' expression. */
class BitAndExpr extends @bitandexpr, BinaryExpr {
  override string getOperator() {
    result = "&"
  }
}

/** An `in` expression. */
class InExpr extends @inexpr, BinaryExpr {
  override string getOperator() {
    result = "in"
  }
}

/** An `instanceof` expression. */
class InstanceofExpr extends @instanceofexpr, BinaryExpr {
  override string getOperator() {
    result = "instanceof"
  }
}

/** A logical 'and' expression. */
class LogAndExpr extends @logandexpr, BinaryExpr {
  override string getOperator() {
    result = "&&"
  }

  override ControlFlowNode getFirstControlFlowNode() { result = this }
}

/** A logical 'or' expression. */
class LogOrExpr extends @logorexpr, BinaryExpr {
  override string getOperator() {
    result = "||"
  }

  override ControlFlowNode getFirstControlFlowNode() { result = this }
}

/**
 * A logical binary expression, that is, either a logical
 * 'or' or a logical 'and' expression.
 */
class LogicalBinaryExpr extends BinaryExpr {
  LogicalBinaryExpr() {
    this instanceof LogAndExpr or
    this instanceof LogOrExpr
  }
}

/**
 * A bitwise binary expression, that is, either a bitwise
 * 'and', a bitwise 'or', or an exclusive 'or' expression.
 */
class BitwiseBinaryExpr extends BinaryExpr {
  BitwiseBinaryExpr() {
    this instanceof BitAndExpr or
    this instanceof BitOrExpr or
    this instanceof XOrExpr
  }
}

/** A shift expression. */
class ShiftExpr extends BinaryExpr {
  ShiftExpr() {
    this instanceof LShiftExpr or
    this instanceof RShiftExpr or
    this instanceof URShiftExpr
  }
}

/** An assignment expression, either compound or simple. */
class Assignment extends @assignment, Expr {
  /** Gets the left hand side of this assignment. */
  Expr getLhs() {
    result = getChildExpr(0)
  }

  /** Gets the right hand side of this assignment. */
  Expr getRhs() {
    result = getChildExpr(1)
  }

  /** Gets the variable or property this assignment writes to, if any. */
  Expr getTarget() {
    result = getLhs().stripParens()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getLhs().getFirstControlFlowNode()
  }
}

/** A simple assignment expression. */
class AssignExpr extends @assignexpr, Assignment {}

/** A compound assign expression. */
abstract class CompoundAssignExpr extends Assignment {}

/** A compound add-assign expression. */
class AssignAddExpr extends @assignaddexpr, CompoundAssignExpr {}

/** A compound subtract-assign expression. */
class AssignSubExpr extends @assignsubexpr, CompoundAssignExpr {}

/** A compound multiply-assign expression. */
class AssignMulExpr extends @assignmulexpr, CompoundAssignExpr {}

/** A compound divide-assign expression. */
class AssignDivExpr extends @assigndivexpr, CompoundAssignExpr {}

/** A compound modulo-assign expression. */
class AssignModExpr extends @assignmodexpr, CompoundAssignExpr {}

/** A compound exponentiate-assign expression. */
class AssignExpExpr extends @assignexpexpr, CompoundAssignExpr {}

/** A compound left-shift-assign expression. */
class AssignLShiftExpr extends @assignlshiftexpr, CompoundAssignExpr {}

/** A compound right-shift-assign expression. */
class AssignRShiftExpr extends @assignrshiftexpr, CompoundAssignExpr {}

/** A compound unsigned-right-shift-assign expression. */
class AssignURShiftExpr extends @assignurshiftexpr, CompoundAssignExpr {}

/** A compound bitwise-'or'-assign expression. */
class AssignOrExpr extends @assignorexpr, CompoundAssignExpr {}

/** A compound exclusive-'or'-assign expression. */
class AssignXOrExpr extends @assignxorexpr, CompoundAssignExpr {}

/** A compound bitwise-'and'-assign expression. */
class AssignAndExpr extends @assignandexpr, CompoundAssignExpr {}

/** An update expression, that is, an increment or decrement expression. */
class UpdateExpr extends @updateexpr, Expr {
  /** Gets the operand of this update. */
  Expr getOperand() {
    result = getChildExpr(0)
  }

  /** Holds if this is a prefix increment or prefix decrement expression. */
  predicate isPrefix() {
    none()
  }

  /** Gets the operator of this update expression. */
  string getOperator() {
    none()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getOperand().getFirstControlFlowNode()
  }
}

/** A prefix increment expression. */
class PreIncExpr extends @preincexpr, UpdateExpr {
  override predicate isPrefix() {
    any()
  }

  override string getOperator() {
    result = "++"
  }
}

/** A postfix increment expression. */
class PostIncExpr extends @postincexpr, UpdateExpr {
  override string getOperator() {
    result = "++"
  }
}

/** A prefix decrement expression. */
class PreDecExpr extends @predecexpr, UpdateExpr {
  override predicate isPrefix() {
    any()
  }

  override string getOperator() {
    result = "--"
  }
}

/** A postfix decrement expression. */
class PostDecExpr extends @postdecexpr, UpdateExpr {
  override string getOperator() {
    result = "--"
  }
}

/** A `yield` expression. */
class YieldExpr extends @yieldexpr, Expr {
  /** Gets the operand of this `yield` expression. */
  Expr getOperand() {
    result = getChildExpr(0)
  }

  /** Holds if this is a `yield*` expression. */
  predicate isDelegating() {
    isDelegating(this)
  }

  override predicate isImpure() {
    any()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getOperand().getFirstControlFlowNode() or
    not exists(getOperand()) and result = this
  }
}

/**
 * A comprehension expression, that is, either an array comprehension
 * expression or a generator expression.
 */
class ComprehensionExpr extends @comprehensionexpr, Expr {
  /** Gets the `n`th comprehension block in this comprehension. */
  ComprehensionBlock getBlock(int n) {
    exists (int idx |
      result = getChildExpr(idx) and
      idx > 0 and
      n = idx-1
    )
  }

  /** Gets a comprehension block in this comprehension. */
  ComprehensionBlock getABlock() {
    result = getBlock(_)
  }

  /** Gets the number of comprehension blocks in this comprehension. */
  int getNumBlock() {
    result = count(getABlock())
  }

  /** Gets the `n`th filter expression in this comprehension. */
  Expr getFilter(int n) {
    exists (int idx |
      result = getChildExpr(idx) and
      idx < 0 and
      n = -idx-1
    )
  }

  /** Gets a filter expression in this comprehension. */
  Expr getAFilter() {
    result = getFilter(_)
  }

  /** Gets the number of filter expressions in this comprehension. */
  int getNumFilter() {
    result = count(getAFilter())
  }

  /** Gets the body expression of this comprehension. */
  Expr getBody() {
    result = getChildExpr(0)
  }

  override predicate isImpure() {
    getABlock().isImpure() or
    getAFilter().isImpure() or
    getBody().isImpure()
  }

  /** Holds if this is a legacy postfix comprehension expression. */
  predicate isPostfix() {
    exists (Token tk | tk = getFirstToken().getNextToken() |
      not tk.getValue().regexpMatch("if|for")
    )
  }
}

/** An array comprehension expression. */
class ArrayComprehensionExpr extends @arraycomprehensionexpr, ComprehensionExpr {
}

/** A generator expression. */
class GeneratorExpr extends @generatorexpr, ComprehensionExpr {
}

/** A comprehension block. */
class ComprehensionBlock extends @comprehensionblock, Expr {
  /** Gets the iterating variable or pattern of this comprehension block. */
  BindingPattern getIterator() {
    result = getChildExpr(0)
  }

  /** Gets the domain over which this comprehension block iterates. */
  Expr getDomain() {
    result = getChildExpr(1)
  }

  override predicate isImpure() {
    getIterator().isImpure() or
    getDomain().isImpure()
  }
}

/** A `for`-`in` comprehension block. */
class ForInComprehensionBlock extends @forincomprehensionblock, ComprehensionBlock {
}

/** A `for`-`of` comprehension block. */
class ForOfComprehensionBlock extends @forofcomprehensionblock, ComprehensionBlock {
}

/** A binary arithmetic expression using `+`, `-`, `/`, `%` or `**`. */
class ArithmeticExpr extends BinaryExpr {
  ArithmeticExpr() {
    this instanceof AddExpr or
    this instanceof SubExpr or
    this instanceof MulExpr or
    this instanceof DivExpr or
    this instanceof ModExpr or
    this instanceof ExpExpr
  }
}

/** A logical expression using `&&`, `||`, or `!`. */
class LogicalExpr extends Expr {
  LogicalExpr() {
    this instanceof LogicalBinaryExpr or
    this instanceof LogNotExpr
  }
}

/** A bitwise expression using `&`, `|`, `^`, `~`, `<<`, `>>`, or `>>>`. */
class BitwiseExpr extends Expr {
  BitwiseExpr() {
    this instanceof BitwiseBinaryExpr or
    this instanceof BitNotExpr or
    this instanceof ShiftExpr
  }
}

/** A strict equality test using `!==` or `===`. */
class StrictEqualityTest extends EqualityTest {
  StrictEqualityTest() {
    this instanceof StrictEqExpr or
    this instanceof StrictNEqExpr
  }
}

/** A non-strict equality test using `!=` or `==`. */
class NonStrictEqualityTest extends EqualityTest {
  NonStrictEqualityTest() {
    this instanceof EqExpr or
    this instanceof NEqExpr
  }
}

/** A relational comparison using `<`, `<=`, `>=`, or `>`. */
class RelationalComparison extends Comparison {
  RelationalComparison() {
    this instanceof LTExpr or
    this instanceof LEExpr or
    this instanceof GEExpr or
    this instanceof GTExpr
  }

  /**
   * Gets the lesser operand of this comparison, that is, the left operand for
   * a `<` or `<=` comparison, and the right operand for `>=` or `>`.
   */
  Expr getLesserOperand() {
    (this instanceof LTExpr or this instanceof LEExpr) and result = getLeftOperand() or
    (this instanceof GTExpr or this instanceof GEExpr) and result = getRightOperand()
  }

  /**
   * Gets the greater operand of this comparison, that is, the right operand for
   * a `<` or `<=` comparison, and the left operand for `>=` or `>`.
   */
  Expr getGreaterOperand() {
    result = getAnOperand() and result != getLesserOperand()
  }

  /**
   * Holds if this is a comparison with `<=` or `>=`.
   */
  predicate isInclusive() {
    this instanceof LEExpr or
    this instanceof GEExpr
  }
}

/** A (pre or post) increment expression. */
class IncExpr extends UpdateExpr {
  IncExpr() { this instanceof PreIncExpr or this instanceof PostIncExpr }
}

/** A (pre or post) decrement expression. */
class DecExpr extends UpdateExpr {
  DecExpr() { this instanceof PreDecExpr or this instanceof PostDecExpr }
}


/** An old-style `let` expression of the form `let(vardecls) expr`. */
class LegacyLetExpr extends Expr, @legacy_letexpr {
  /** Gets the `i`th declarator in this `let` expression. */
  VariableDeclarator getDecl(int i) {
    result = getChildExpr(i) and i >= 0
  }

  /** Gets a declarator in this declaration expression. */
  VariableDeclarator getADecl() {
    result = getDecl(_)
  }

  /** Gets the expression this `let` expression scopes over. */
  Expr getBody() {
    result = getChildExpr(-1)
  }
}

/** An immediately invoked function expression (IIFE). */
class ImmediatelyInvokedFunctionExpr extends Function {
  /** The invocation expression of this IIFE. */
  InvokeExpr invk;

  /**
   * The kind of invocation by which this IIFE is invoked: `"call"`
   * for a direct function call, `"call"` or `"apply"` for a reflective
   * invocation through `call` or `apply`, respectively.
   */
  string kind;

  ImmediatelyInvokedFunctionExpr() {
    // direct call
    this = invk.getCallee().stripParens() and kind = "direct" or
    // reflective call
    exists (MethodCallExpr mce | mce = invk |
      this = mce.getReceiver().stripParens() and
      kind = mce.getMethodName() and
      (kind = "call" or kind = "apply")
    )
  }

  /** Gets the invocation of this IIFE. */
  InvokeExpr getInvocation() {
    result = invk
  }

  /**
   * Gets a string describing the way this IIFE is invoked
   * (one of `"direct"`, `"call"` or `"apply"`).
   */
  string getInvocationKind() {
    result = kind
  }

  /**
   * Gets the `i`th argument of this IIFE.
   */
  Expr getArgument(int i) {
    result = invk.getArgument(i)
  }

  /**
   * Holds if the `i`th argument of this IIFE is a spread element.
   */
  predicate isSpreadArgument(int i) {
    invk.isSpreadArgument(i)
  }

  /**
   * Gets the offset of argument positions relative to parameter
   * positions: for direct IIFEs the offset is zero, for IIFEs
   * using `Function.prototype.call` the offset is one, and for
   * IIFEs using `Function.prototype.apply` the offset is not defined.
   */
  int getArgumentOffset() {
    kind = "direct" and result = 0 or
    kind = "call" and result = 1
  }

  /**
   * Holds if `p` is a parameter of this IIFE and `arg` is
   * the corresponding argument.
   *
   * Note that rest parameters do not have corresponding arguments;
   * conversely, arguments after a spread element do not have a corresponding
   * parameter.
   */
  predicate argumentPassing(Parameter p, Expr arg) {
    exists (int parmIdx, int argIdx |
      p = getParameter(parmIdx) and not p.isRestParameter() and
      argIdx = parmIdx + getArgumentOffset() and arg = getArgument(argIdx) and
      not isSpreadArgument([0..argIdx])
    )
  }
}

/** An `await` expression. */
class AwaitExpr extends @awaitexpr, Expr {
  /** Gets the operand of this `await` expression. */
  Expr getOperand() {
    result = getChildExpr(0)
  }

  override predicate isImpure() {
    any()
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getOperand().getFirstControlFlowNode()
  }
}

/**
 * A `function.sent` expression.
 *
 * Inside a generator function, `function.sent` evaluates to the value passed
 * to the generator by the `next` method that most recently resumed execution
 * of the generator.
 */
class FunctionSentExpr extends @functionsentexpr, Expr {
  override predicate isImpure() {
    none()
  }
}

/**
 * A decorator applied to a class, property or member definition.
 *
 * For example, in the class declaration `@A class C { }`,
 * `@A` is a decorator applied to class `C`.
 */
class Decorator extends @decorator, Expr {
  /**
   * Gets the element this decorator is applied to.
   *
   * For example, in the class declaration `@A class C { }`,
   * the element decorator `@A` is applied to is `C`.
   */
  Decoratable getElement() {
    this = result.getADecorator()
  }

  /**
   * Gets the expression of this decorator.
   *
   * For example, the decorator `@A` has expression `A`,
   * and `@testable(true)` has expression `testable(true)`.
   */
  Expr getExpression() {
    result = getChildExpr(0)
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getExpression().getFirstControlFlowNode()
  }
}

/**
 * A program element to which decorators can be applied,
 * that is, a class, a property or a member definition.
 */
class Decoratable extends ASTNode {
  Decoratable() {
    this instanceof ClassDefinition or
    this instanceof Property or
    this instanceof MemberDefinition or
    this instanceof EnumDeclaration or
    this instanceof Parameter
  }

  /**
   * Gets the `i`th decorator applied to this element.
   */
  Decorator getDecorator(int i) {
    result = this.(ClassDefinition).getDecorator(i) or
    result = this.(Property).getDecorator(i) or
    result = this.(MemberDefinition).getDecorator(i) or
    result = this.(EnumDeclaration).getDecorator(i) or
    result = this.(Parameter).getDecorator(i)
  }

  /**
   * Gets a decorator applied to this element, if any.
   */
  Decorator getADecorator() {
    result = this.getDecorator(_)
  }
}

/**
 * A function bind expression either of the form `b::f`, or of the
 * form `::b.f`.
 */
class FunctionBindExpr extends @bindexpr, Expr {
  /**
   * Gets the object of this function bind expression; undefined for
   * expressions of the form `::b.f`.
   */
  Expr getObject() {
    result = getChildExpr(0)
  }

  /** Gets the callee of this function bind expression. */
  Expr getCallee() {
    result = getChildExpr(1)
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getObject().getFirstControlFlowNode() or
    not exists(getObject()) and result = getCallee().getFirstControlFlowNode()
  }
}

/**
 * A dynamic import expression of the form `import(source)`.
 */
class DynamicImportExpr extends @dynamicimport, Expr, Import {
  /** Gets the expression specifying the path of the imported module. */
  Expr getSource() {
    result = getChildExpr(0)
  }

  override ControlFlowNode getFirstControlFlowNode() {
    result = getSource().getFirstControlFlowNode()
  }

  override PathExpr getImportedPath() {
    result = getSource()
  }

  override Module getEnclosingModule() {
    result = getTopLevel()
  }
}


/** A literal path expression appearing in a dynamic import. */
private class LiteralDynamicImportPath extends PathExprInModule, ConstantString {
  LiteralDynamicImportPath() {
    exists (DynamicImportExpr di | this.getParentExpr*() = di.getSource())
  }

  override string getValue() { result = this.(ConstantString).getStringValue() }
}