/**
 * INTERNAL: Do not use directly; use `semmle.javascript.dataflow.TypeInference` instead.
 *
 * Provides classes implementing type inference across imports.
 */

import javascript
private import AbstractValuesImpl
private import semmle.javascript.dataflow.InferredTypes
private import AbstractPropertiesImpl

/**
 * Flow analysis for ECMAScript 2015 imports as variable definitions.
 */
private class AnalyzedImportSpecifier extends AnalyzedVarDef, @importspecifier {
  ImportDeclaration id;

  AnalyzedImportSpecifier() {
    this = id.getASpecifier() and exists(id.resolveImportedPath())
  }

  override DataFlow::AnalyzedNode getRhs() {
    result.(AnalyzedImport).getImportSpecifier() = this
  }

  override predicate isIncomplete(DataFlow::Incompleteness cause) {
    // mark as incomplete if the import could rely on the lookup path
    mayDependOnLookupPath(id.getImportedPath().getValue()) and
    cause = "import"
    or
    // mark as incomplete if we cannot fully analyze this import
    exists (Module m | m = id.resolveImportedPath() |
      mayDynamicallyComputeExports(m)
      or
      incompleteExport(m, this.(ImportSpecifier).getImportedName())
    ) and
    cause = "import"
  }
}

/**
 * Holds if resolving `path` may depend on the lookup path, that is,
 * it does not start with `.` or `/`.
 */
bindingset[path]
private predicate mayDependOnLookupPath(string path) {
  exists (string firstChar | firstChar = path.charAt(0) |
    firstChar != "." and firstChar != "/"
  )
}

/**
 * Holds if `m` may dynamically compute its exports.
 */
private predicate mayDynamicallyComputeExports(Module m) {
  // if `m` accesses its `module` or `exports` variable, we conservatively assume the worst;
  // in particular, this makes all imports from CommonJS modules indefinite
  exists (Variable v, VarAccess va | v.getName() = "module" or v.getName() = "exports" |
    va = v.getAnAccess() and
    (
      v = m.getScope().getAVariable()
      or
      // be conservative in case our heuristics for detecting Node.js modules fail
      v instanceof GlobalVariable and va.getTopLevel() = m
    )
  )
  or
  // AMD modules can export arbitrary objects, so an import is essentially a property read
  // and hence must be considered indefinite
  m instanceof AMDModule
  or
  // `m` re-exports all exports of some other module that dynamically computes its exports
  exists (BulkReExportDeclaration rexp | rexp = m.(ES2015Module).getAnExport() |
    mayDynamicallyComputeExports(rexp.getImportedModule())
  )
}

/**
 * Holds if `x` is imported from `m`, possibly through a chain of re-exports.
 */
private predicate relevantExport(ES2015Module m, string x) {
  exists (ImportDeclaration id |
    id.getImportedModule() = m and
    x = id.getASpecifier().getImportedName()
  )
  or
  exists (ReExportDeclaration rexp, string y |
    rexp.getImportedModule() = m and
    reExportsAs(rexp, x, y)
  )
}

/**
 * Holds if `rexp` re-exports `x` as `y`.
 */
private predicate reExportsAs(ReExportDeclaration rexp, string x, string y) {
  relevantExport(rexp.getEnclosingModule(), y) and
  (
   exists (ExportSpecifier spec | spec = rexp.(SelectiveReExportDeclaration).getASpecifier() |
     x = spec.getLocalName() and
     y = spec.getExportedName()
   )
   or
   rexp instanceof BulkReExportDeclaration and
   x = y
  )
}

/**
 * Holds if `m` re-exports `y`, but we cannot fully analyze this export.
 */
private predicate incompleteExport(ES2015Module m, string y) {
  exists (ReExportDeclaration rexp | rexp = m.getAnExport() |
    exists (string x | reExportsAs(rexp, x, y) |
      // path resolution could rely on lookup path
      mayDependOnLookupPath(rexp.getImportedPath().getStringValue())
      or
      // unresolvable path
      not exists(rexp.getImportedModule())
      or
      exists (Module n | n = rexp.getImportedModule() |
        // re-export from CommonJS/AMD
        mayDynamicallyComputeExports(n)
        or
        // recursively incomplete
        incompleteExport(n, x)
      )
    )
    or
    // namespace re-export
    exists (ExportNamespaceSpecifier ns |
      ns.getExportDeclaration() = rexp and
      ns.getExportedName() = y
    )
  )
}

/**
 * Flow analysis for import specifiers, interpreted as implicit reads of
 * properties of the `module.exports` object of the imported module.
 */
private class AnalyzedImport extends AnalyzedPropertyRead, DataFlow::ValueNode {
  Module imported;

  AnalyzedImport() {
    exists (ImportDeclaration id |
      astNode = id.getASpecifier() and
      imported = id.getImportedModule()
    )
  }

  /** Gets the import specifier being analyzed. */
  ImportSpecifier getImportSpecifier() {
    result = astNode
  }

  override predicate reads(AbstractValue base, string propName) {
    exists (AbstractProperty exports |
      exports = MkAbstractProperty(TAbstractModuleObject(imported), "exports") |
      base = exports.getALocalValue() and
      propName = astNode.(ImportSpecifier).getImportedName()
    )
    or
    // when importing CommonJS/AMD modules from ES2015, `module.exports` appears
    // as the default export
    not imported instanceof ES2015Module and
    astNode.(ImportSpecifier).getImportedName() = "default" and
    base = TAbstractModuleObject(imported) and
    propName = "exports"
  }
}

/**
 * Flow analysis for namespace imports.
 */
private class AnalyzedNamespaceImport extends AnalyzedImport {
  override ImportNamespaceSpecifier astNode;

  override predicate reads(AbstractValue base, string propName) {
    base = TAbstractModuleObject(imported) and
    propName = "exports"
  }
}

/**
 * Flow analysis for `require` calls, interpreted as an implicit read of
 * the `module.exports` property of the imported module.
 */
class AnalyzedRequireCall extends AnalyzedPropertyRead, DataFlow::ValueNode {
  Module required;

  AnalyzedRequireCall() {
    required = astNode.(Require).getImportedModule()
  }

  override predicate reads(AbstractValue base, string propName) {
    base = TAbstractModuleObject(required) and
    propName = "exports"
  }
}

/**
 * Flow analysis for special TypeScript `require` calls in an import-assignment.
 */
class AnalyzedExternalModuleReference extends AnalyzedPropertyRead, DataFlow::ValueNode {
  Module required;

  AnalyzedExternalModuleReference() {
    required = astNode.(ExternalModuleReference).getImportedModule()
  }

  override predicate reads(AbstractValue base, string propName) {
    base = TAbstractModuleObject(required) and
    propName = "exports"
  }
}

/**
 * Flow analysis for AMD exports.
 */
private class AnalyzedAmdExport extends AnalyzedPropertyWrite, DataFlow::ValueNode {
  AMDModule amd;

  AnalyzedAmdExport() {
    astNode = amd.getDefine().getModuleExpr()
  }

  override predicate writes(AbstractValue baseVal, string propName, DataFlow::AnalyzedNode source) {
    baseVal = TAbstractModuleObject(amd) and
    propName = "exports" and
    source = this
  }
}

/**
 * Flow analysis for exports that export a single value.
 */
private class AnalyzedValueExport extends AnalyzedPropertyWrite, DataFlow::ValueNode {
  ExportDeclaration export;
  string name;

  AnalyzedValueExport() {
    this = export.getSourceNode(name)
  }

  override predicate writes(AbstractValue baseVal, string propName, DataFlow::AnalyzedNode source) {
    baseVal = TAbstractExportsObject(export.getEnclosingModule()) and
    propName = name and
    source = export.getSourceNode(name).analyze()
  }
}

/**
 * Flow analysis for exports that export a binding.
 */
private class AnalyzedVariableExport extends AnalyzedPropertyWrite, DataFlow::ValueNode {
  ExportDeclaration export;
  string name;
  AnalyzedVarDef varDef;

  AnalyzedVariableExport() {
    export.exportsAs(varDef.getAVariable(), name) and
    astNode = varDef.getTarget()
  }

  override predicate writes(AbstractValue baseVal, string propName, DataFlow::AnalyzedNode source) {
    baseVal = TAbstractExportsObject(export.getEnclosingModule()) and
    propName = name and
    source = varDef.getRhsNode().analyze()
  }
}

/**
 * Flow analysis for default exports.
 */
private class AnalyzedDefaultExportDeclaration extends AnalyzedValueExport {
  override ExportDefaultDeclaration export;

  override predicate writes(AbstractValue baseVal, string propName, DataFlow::AnalyzedNode source) {
    super.writes(baseVal, propName, source)
    or
    // some (presumably historic) transpilers treat `export default foo` as `module.exports = foo`,
    // so allow that semantics, too, but only if there isn't a named export in the same module.
    exists (Module m |
      super.writes(TAbstractExportsObject(m), "default", source) and
      baseVal = TAbstractModuleObject(m) and
      propName = "exports" and
      not m.(ES2015Module).getAnExport() instanceof ExportNamedDeclaration
    )
  }
}

/**
 * Flow analysis for TypeScript export assignments.
 */
private class AnalyzedExportAssign extends AnalyzedPropertyWrite, DataFlow::ValueNode {
  ExportAssignDeclaration exportAssign;

  AnalyzedExportAssign() {
    astNode = exportAssign.getExpression()
  }

  override predicate writes(AbstractValue baseVal, string propName, DataFlow::AnalyzedNode source) {
    baseVal = TAbstractModuleObject(exportAssign.getContainer()) and
    propName = "exports" and
    source = this
  }
}
