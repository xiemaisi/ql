/** Provides classes and predicates for working with variable definitions and uses. */

import javascript

private module Impl {
  abstract class VarDefImpl extends ControlFlowNode {
    abstract Expr getLhs();

    AST::ValueNode getRhs() { none() }

    DataFlow::Node getRhsNode() { result = getRhs().flow() }
  }

  /**
   * Holds if `def` is a CFG node that assigns the value of `rhs` to `lhs`.
   *
   * This predicate covers four kinds of definitions:
   *
   * <table border="1">
   * <tr><th>Example<th><code>def</code><th><code>lhs</code><th><code>rhs</code></tr>
   * <tr><td><code>x = y</code><td><code>x = y</code><td><code>x</code><td><code>y</code></tr>
   * <tr><td><code>var a = b</code><td><code>var a = b</code><td><code>a</code><td><code>b</code></tr>
   * <tr><td><code>function f { ... }</code><td><code>f</code><td><code>f</code><td><code>function f { ... }</code></tr>
   * <tr><td><code>class C { ... }</code><td><code>C</code><td><code>C</code><td><code>class C { ... }</code></tr>
   * <tr><td><code>namespace N { ... }</code><td><code>N</code><td><code>N</code><td><code>namespace N { ... }</code></tr>
   * <tr><td><code>enum E { ... }</code><td><code>E</code><td><code>E</code><td><code>enum E { ... }</code></tr>
   * <tr><td><code>import x = y</code><td><code>x</code><td><code>x</code><td><code>y</code></tr>
   * <tr><td><code>enum { x = y }</code><td><code>x</code><td><code>x</code><td><code>y</code></tr>
   * </table>
   *
   * Note that `def` and `lhs` are not in general the same: the latter
   * represents the point where `lhs` is evaluated to an assignable reference,
   * the former the point where the value of `rhs` is actually assigned
   * to that reference.
   */
  class VarDefWithSyntacticRhs extends VarDefImpl {
    Expr lhs;
    AST::ValueNode rhs;

    VarDefWithSyntacticRhs() {
      exists (AssignExpr assgn | this = assgn |
        lhs = assgn.getTarget() and rhs = assgn.getRhs()
      ) or
      exists (VariableDeclarator vd | this = vd |
        lhs = vd.getBindingPattern() and rhs = vd.getInit()
      ) or
      exists (Function f | this = f.getId() |
        lhs = this and rhs = f
      ) or
      exists (ClassDefinition c | lhs = c.getIdentifier() |
        this = c and rhs = c and not c.isAmbient()
      ) or
      exists (NamespaceDeclaration n | this = n |
        lhs = n.getId() and rhs = n
      ) or
      exists (EnumDeclaration ed | this = ed.getIdentifier() |
        lhs = this and rhs = ed
      ) or
      exists (ImportEqualsDeclaration i | this = i |
        lhs = i.getId() and rhs = i.getImportedEntity()
      ) or
      exists (EnumMember member | this = member.getIdentifier() |
        lhs = this and rhs = member.getInitializer()
      )
    }

    override Expr getLhs() {
      result = lhs
    }

    override AST::ValueNode getRhs() {
      result = rhs
    }
  }

  class UpdateDef extends VarDefImpl {
    UpdateExpr upd;

    UpdateDef() {
      this = upd
    }

    override Expr getLhs() {
      result = upd.getOperand().stripParens()
    }

    override DataFlow::Node getRhsNode() {
      result.(DataFlow::UpdateExprRhs).getUpdateExpr() = upd
    }
  }

  class CompoundDef extends VarDefImpl {
    CompoundAssignExpr assgn;

    CompoundDef() {
      this = assgn
    }

    override Expr getLhs() {
      result = assgn.getTarget()
    }

    override DataFlow::Node getRhsNode() {
      result.(DataFlow::CompoundAssignExprRhs).getAssignment() = assgn
    }
  }

  class IteratorDef extends VarDefImpl {
    IteratorDef() {
      DataFlow::iterator(this, _, _, _)
    }

    override Expr getLhs() {
      DataFlow::iterator(this, _, result, _)
    }

    override DataFlow::Node getRhsNode() {
      DataFlow::iterator(this, _, _, result.(DataFlow::Iterator).getIterand())
    }
  }

  class EnumMemberWithImplicitInit extends VarDefImpl {
    EnumMember em;

    EnumMemberWithImplicitInit() {
      this = em.getIdentifier() and not exists(em.getInitializer())
    }

    override Expr getLhs() {
      result = em.getIdentifier()
    }

    override DataFlow::Node getRhsNode() {
      result.(DataFlow::ImplicitEnumInit).getEnumMember() = em
    }
  }

  class ImportSpecifierVarDef extends VarDefImpl {
    ImportSpecifier is;

    ImportSpecifierVarDef() {
      this = is
    }

    override Expr getLhs() {
      result = is.getLocal()
    }

    override DataFlow::Node getRhsNode() {
      if is instanceof ImportNamespaceSpecifier then
        // for namespace imports, the entire import is the rhs
        result.(DataFlow::ImportNode).getDeclaration() = is.getImportDeclaration()
      else
        // for symbol imports, the specifier itself (which is interpreted as a
        // property read) is the rhs
        result.(DataFlow::ImportSpecifierAsPropRead).getSpecifier() = is
    }
  }

  class ParameterVarDef extends VarDefImpl {
    Parameter p;

    ParameterVarDef() {
      this = p
    }

    override Expr getLhs() {
      result = p
    }

    override DataFlow::Node getRhsNode() {
      result = DataFlow::parameterNode(p)
    }
  }
}
private import Impl

/**
 * Holds if `l` is one of the lvalues in the assignment `def`, or
 * a destructuring pattern that contains some of the lvalues.
 *
 * For example, if `def` is `[{ x: y }] = e`, then `l` can be any
 * of `y`, `{ x: y }` and `[{ x: y }]`.
 */
private predicate lvalAux(Expr l, VarDefImpl def) {
  l = def.getLhs()
  or
  exists (ArrayPattern ap | lvalAux(ap, def) | l = ap.getAnElement().stripParens())
  or
  exists (ObjectPattern op | lvalAux(op, def) |
    l = op.getAPropertyPattern().getValuePattern().stripParens()
  )
}

/**
 * An expression that can be evaluated to a reference, that is,
 * a variable reference or a property access.
 */
class RefExpr extends Expr {
  RefExpr() {
    this instanceof VarRef or
    this instanceof PropAccess
  }
}

/**
 * A variable reference or property access that is written to.
 *
 * For instance, in the assignment `x.p = x.q`, `x.p` is written to
 * and `x.q` is not; in the expression `++i`, `i` is written to
 * (and also read from).
 */
class LValue extends RefExpr {
  LValue() { lvalAux(this, _) }

  /** Gets the definition in which this lvalue occurs. */
  ControlFlowNode getDefNode() { lvalAux(this, result) }

  /** Gets the source of the assignment. */
  AST::ValueNode getRhs() {
    exists (VarDefImpl def |
      this = def.getLhs() and
      result = def.getRhs()
    )
  }
}

/**
 * A variable reference or property access that is read from.
 *
 * For instance, in the assignment `x.p = x.q`, `x.q` is read from
 * and `x.p` is not; in the expression `++i`, `i` is read from
 * (and also written to).
 */
class RValue extends RefExpr {
  RValue() {
    not this instanceof LValue and not this instanceof VarDecl or
    // in `x++` and `x += 1`, `x` is both RValue and LValue
    this = any(CompoundAssignExpr a).getTarget() or
    this = any(UpdateExpr u).getOperand().stripParens() or
    this = any(NamespaceDeclaration decl).getId()
  }
}

/**
 * A ControlFlowNode that defines (that is, initializes or updates) variables or properties.
 *
 * The following program elements are definitions:
 *
 * - assignment expressions (`x = 42`)
 * - update expressions (`++x`)
 * - variable declarators with an initializer (`var x = 42`)
 * - for-in and for-of statements (`for (x in o) { ... }`)
 * - parameters of functions or catch clauses (`function (x) { ... }`)
 * - named functions (`function x() { ... }`)
 * - named classes (`class x { ... }`)
 * - import specifiers (`import { x } from 'm'`)
 *
 * Note that due to destructuring, a single `VarDef` may define multiple
 * variables and/or properties; for example, `{ x, y: z.p } = e` defines variable
 * `x` as well as property `p` of `z`.
 */
class VarDef extends ControlFlowNode {
  VarDefImpl impl;

  VarDef() {
    this = impl
  }

  /**
   * Gets the target of this definition, which is either a simple variable
   * reference, a destructuring pattern, or a property access.
   */
  Expr getTarget() {
    result = impl.getLhs()
  }

  /** Gets a variable defined by this node, if any. */
  Variable getAVariable() {
    result = getTarget().(BindingPattern).getAVariable()
  }

  /**
   * Gets the source of this definition, that is, the data flow node representing
   * the value that this definition assigns to its target.
   *
   * This predicate is not defined for `VarDef`s where the source is implicit,
   * such as `for-in` loops or parameters.
   */
  AST::ValueNode getSource() {
    result = impl.getRhs()
  }

  DataFlow::Node getRhsNode() {
    result = impl.getRhsNode()
  }

  /**
   * Holds if this definition of `v` is overwritten by another definition, that is,
   * another definition of `v` is reachable from it in the CFG.
   */
  predicate isOverwritten(Variable v) {
    exists (BasicBlock bb, int i | bb.defAt(i, v, this) |
      exists (int j | bb.defAt(j, v, _) and j > i) or
      bb.getASuccessor+().defAt(_, v, _)
    )
  }
}

/**
 * A ControlFlowNode that uses (that is, reads from) a single variable.
 *
 * Some variable definitions are also uses, notably the operands of update expressions.
 */
class VarUse extends ControlFlowNode, @varref {
  VarUse() {
    this instanceof RValue
  }

  /** Gets the variable this use refers to. */
  Variable getVariable() {
    result = this.(VarRef).getVariable()
  }

  /**
   * Gets a definition that may reach this use.
   *
   * For global variables, each definition is considered to reach each use.
   */
  VarDef getADef() {
    result = getSsaVariable().getDefinition().getAContributingVarDef() or
    result.getAVariable() = (GlobalVariable)getVariable()
  }

  /**
   * Gets the unique SSA variable this use refers to.
   *
   * This predicate is only defined for variables that can be SSA-converted.
   */
  SsaVariable getSsaVariable() {
    result.getAUse() = this
  }
}

/**
 * Holds if the definition of `v` in `def` reaches `use` along some control flow path
 * without crossing another definition of `v`.
 */
predicate definitionReaches(Variable v, VarDef def, VarUse use) {
  v = use.getVariable() and
  exists (BasicBlock bb, int i, int next |
    next = nextDefAfter(bb, v, i, def) |
    exists (int j | j in [i+1..next-1] | bb.useAt(j, v, use)) or
    exists (BasicBlock succ | succ = bb.getASuccessor() |
      succ.isLiveAtEntry(v, use) and
      next = bb.length()
    )
  )
}

/**
 * Holds if the definition of local variable `v` in `def` reaches `use` along some control flow path
 * without crossing another definition of `v`.
 */
predicate localDefinitionReaches(LocalVariable v, VarDef def, VarUse use) {
  exists (SsaExplicitDefinition ssa |
    ssa.defines(def, v) and
    ssa = getAPseudoDefinitionInput*(use.getSsaVariable().getDefinition())
  )
}

/** Holds if `nd` is a pseudo-definition and the result is one of its inputs. */
private SsaDefinition getAPseudoDefinitionInput(SsaDefinition nd) {
  result = nd.(SsaPseudoDefinition).getAnInput()
}

/**
 * Holds if `d` is a definition of `v` at index `i` in `bb`, and the result is the next index
 * in `bb` after `i` at which the same variable is defined, or `bb.length()` if there is none.
 */
private int nextDefAfter(BasicBlock bb, Variable v, int i, VarDef d) {
  bb.defAt(i, v, d) and
  result = min(int jj | (bb.defAt(jj, v, _) or jj = bb.length()) and jj > i)
}

/**
 * Holds if the `later` definition of `v` could overwrite its `earlier` definition.
 *
 * This is the case if there is a path from `earlier` to `later` that does not cross
 * another definition of `v`.
 */
predicate localDefinitionOverwrites(LocalVariable v, VarDef earlier, VarDef later) {
  exists (BasicBlock bb, int i, int next |
    next = nextDefAfter(bb, v, i, earlier) |
    bb.defAt(next, v, later) or
    exists (BasicBlock succ | succ = bb.getASuccessor() |
      succ.localMayBeOverwritten(v, later) and
      next = bb.length()
    )
  )
}
