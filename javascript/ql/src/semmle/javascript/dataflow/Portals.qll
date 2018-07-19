/**
 * Provides models of "portals", that is, interface points between different
 * npm packages. A typical example of a portal is a parameter of a function
 * exported by an npm package.
 *
 * Portals have entry and exit nodes. For example, the (unique) exit node of
 * the parameter of an exported function is the `ParameterNode` corresponding
 * to that parameter, while its entries are all nodes corresponding to arguments
 * passed into the parameter via a call.
 */

import javascript

private newtype TPortal =
  MkNpmPackagePortal(string pkgName) {
    NpmPackagePortal::imports(_, pkgName) or
    NpmPackagePortal::imports(_, pkgName, _) or
    NpmPackagePortal::exports(pkgName, _)
  }
  or
  MkPortalProperty(Portal base, boolean isStatic, string prop) {
    (
     PortalProperty::reads(base, isStatic, prop, _, _) or
     PortalProperty::writes(base, isStatic, prop, _, _)
    ) and
    // only consider alpha-numeric properties, excluding special properties
    // and properties whose names look like they are meant to be internal
    prop.regexpMatch("(?!prototype$|__)[a-zA-Z_]\\w*")
  }
  or
  MkPortalParameter(Portal base, int i) {
    PortalParameter::parameter(base, i, _, _) or
    PortalParameter::argument(base, i, _, _)
  }
  or
  MkPortalReturn(Portal base) {
    PortalReturn::calls(_, base, _) or
    PortalReturn::returns(base, _, _)
  }

/**
 * A portal, that is, an interface point between different npm packages.
 */
class Portal extends TPortal {
  /**
   * Gets an exit node for this portal, that is, a node from which data
   * that comes through the portal emerges. The flag `isUserControlled`
   * indicates whether data read from this node may come from a client
   * package.
   */
  abstract DataFlow::SourceNode getAnExitNode(boolean isUserControlled);

  /**
   * Gets an entry node for this portal, that is, a node through which data
   * enters the portal. The flag `escapes` indicates whether data written to
   * the node may escape to a client package.
   */
  abstract DataFlow::Node getAnEntryNode(boolean escapes);

  /**
   * Gets a textual representation of this portal.
   *
   * Different portals must have different `toString`s, so the result of
   * this predicate can be used to uniquely identify a portal.
   */
  abstract string toString();

  /**
   * INTERNAL: Do not use outside this library.
   *
   * The constructor depth of this portal.
   */
  abstract int depth();
}

/**
 * A portal representing the exports value of the main module of an npm
 * package (that is, a value of `module.exports` for CommonJS modules, or
 * the module namespace object for ES2015 modules).
 *
 * Assignments to `module.exports` are entries to this portal, while
 * imports are exits.
 */
private class NpmPackagePortal extends Portal, MkNpmPackagePortal {
  string pkgName;

  NpmPackagePortal() {
    this = MkNpmPackagePortal(pkgName)
  }

  override DataFlow::SourceNode getAnExitNode(boolean isUserControlled) {
    NpmPackagePortal::imports(result, pkgName) and
    isUserControlled = false
  }

  override DataFlow::Node getAnEntryNode(boolean escapes) {
    NpmPackagePortal::exports(pkgName, result) and
    escapes = true
  }

  override string toString() { result = "(package " + pkgName + ")" }

  override int depth() { result = 1 }
}

private module NpmPackagePortal {
  predicate imports(DataFlow::SourceNode imp, string pkgName) {
    imp = DataFlow::moduleImport(pkgName) and
    exists (NPMPackage pkg |
      imp.getTopLevel() = pkg.getAModule() and
      pkg.getPackageJSON().declaresDependency(pkgName, _)
    )
  }

  predicate imports(DataFlow::SourceNode imp, string pkgName, string member) {
    imp = DataFlow::moduleMember(pkgName, member) and
    exists (NPMPackage pkg |
      imp.getTopLevel() = pkg.getAModule() and
      pkg.getPackageJSON().declaresDependency(pkgName, _)
    )
  }

  predicate exports(string pkgName, DataFlow::Node exp) {
    exists (PackageJSON pkg, Module m |
      not pkg.isPrivate() and pkg.getPackageName() = pkgName and
      m = pkg.getMainModule() |
      exists (AnalyzedPropertyWrite apw |
        apw.writes(m.(AnalyzedModule).getModuleObject(), "exports", exp)
      )
      or
      m.(ES2015Module).exports("default", exp.(DataFlow::ValueNode).getAstNode())
    )
  }
}

/**
 * Gets the maximum depth a portal may have.
 *
 * This is a somewhat crude way of preventing us from constructing infinitely many portals.
 */
private int maxdepth() {
  result = 5
}

/**
 * A portal that is constructed over some base portal.
 */
private abstract class CompoundPortal extends Portal {
  Portal base;

  bindingset[this]
  CompoundPortal() {
    // bound size of portal to prevent infinite recursion
    base.depth() < maxdepth()
  }

  override int depth() { result = base.depth() + 1 }
}

/**
 * A portal corresponding to a named property of another portal.
 */
private class PortalProperty extends CompoundPortal, MkPortalProperty {
  boolean isStatic;
  string prop;

  PortalProperty() { this = MkPortalProperty(base, isStatic, prop) }

  override DataFlow::SourceNode getAnExitNode(boolean isUserControlled) {
    PortalProperty::reads(base, isStatic, prop, result, isUserControlled)
  }

  override DataFlow::Node getAnEntryNode(boolean escapes) {
    PortalProperty::writes(base, isStatic, prop, result, escapes)
  }

  override string toString() { result = "(property " + base + " " + isStatic + " " + prop + ")" }
}

private module PortalProperty {
  private predicate portalInstanceAccess(Portal base, DataFlow::SourceNode nd, boolean isUserControlled) {
    exists (AbstractInstance i |
      base.getAnEntryNode(isUserControlled).getALocalSource() = DataFlow::valueNode(i.getConstructor().getDefinition()) and
      nd.analyze().getAValue() = i
    )
    or
    nd = base.getAnExitNode(isUserControlled).getAnInstantiation()
  }

  private DataFlow::SourceNode portalBaseRef(Portal base, boolean isStatic, boolean escapes) {
    result = base.getAnExitNode(escapes) and
    isStatic = true
    or
    result = base.getAnEntryNode(escapes).getALocalSource() and
    isStatic = true
    or
    portalInstanceAccess(base, result, escapes) and
    isStatic = false
  }

  predicate reads(Portal base, boolean isStatic, string prop, DataFlow::SourceNode read, boolean isUserControlled) {
    read = portalBaseRef(base, isStatic, isUserControlled).getAPropertyRead(prop)
    or
    exists (string pkg |
      NpmPackagePortal::imports(read, pkg, prop) and
      base = MkNpmPackagePortal(pkg) and
      isUserControlled = false and
      isStatic = true
    )
  }

  predicate writes(Portal base, boolean isStatic, string prop, DataFlow::Node rhs, boolean escapes) {
    portalBaseRef(base, isStatic, escapes).hasPropertyWrite(prop, rhs)
    or
    exists (PackageJSON pkg, AnalyzedModule m |
      not pkg.isPrivate() and base = MkNpmPackagePortal(pkg.getPackageName()) and
      m = pkg.getMainModule() |
      exists (AnalyzedPropertyWrite apw |
        apw.writes(m.(AnalyzedModule).getAnExportsValue(), prop, rhs)
      ) and
      escapes = true and
      isStatic = true
    )
  }
}

/**
 * A portal corresponding to a positional parameter of another portal.
 */
private class PortalParameter extends CompoundPortal, MkPortalParameter {
  int i;

  PortalParameter() { this = MkPortalParameter(base, i) }

  override DataFlow::SourceNode getAnExitNode(boolean isUserControlled) {
    PortalParameter::parameter(base, i, result, isUserControlled)
  }

  override DataFlow::Node getAnEntryNode(boolean escapes) {
    PortalParameter::argument(base, i, result, escapes)
  }

  override string toString() { result = "(parameter " + base + " " + i + ")" }
}

private module PortalParameter {
  predicate parameter(Portal base, int i, DataFlow::SourceNode param, boolean isUserControlled) {
    param = base.getAnEntryNode(isUserControlled).getALocalSource().(DataFlow::FunctionNode).getParameter(i)
  }

  predicate argument(Portal base, int i, DataFlow::Node arg, boolean escapes) {
    exists (DataFlow::InvokeNode invk |
      invk = base.getAnExitNode(escapes).getAnInvocation() and
      arg = invk.getArgument(i)
    )
  }
}

/**
 * A portal corresponding to the return value of another portal.
 */
private class PortalReturn extends CompoundPortal, MkPortalReturn {
  PortalReturn() { this = MkPortalReturn(base) }

  override DataFlow::SourceNode getAnExitNode(boolean isUserControlled) {
    PortalReturn::calls(result, base, isUserControlled)
  }

  override DataFlow::Node getAnEntryNode(boolean escapes) {
    PortalReturn::returns(base, result, escapes)
  }

  override string toString() { result = "(return " + base + ")" }
}

private module PortalReturn {
  predicate calls(DataFlow::InvokeNode invk, Portal callee, boolean isUserControlled) {
    invk = callee.getAnExitNode(isUserControlled).getAnInvocation()
  }

  predicate returns(Portal base, DataFlow::Node ret, boolean escapes) {
    ret = base.getAnEntryNode(escapes).getALocalSource().(DataFlow::FunctionNode).getAReturn()
  }
}
