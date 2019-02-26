/**
 * Combined points-to and type-inference for "run-time" (as opposed to "import-time" values)
 * The main relation `runtime_points_to(node, object, cls, origin)` relates a control flow node
 * to the possible objects it points-to the inferred types of those objects and the 'origin'
 * of those objects. The 'origin' is the point in source code that the object can be traced
 * back to.
 * 
 * This file contains non-layered parts of the points-to analysis.
 */
import python
import semmle.python.dataflow.SsaDefinitions

module BasePointsTo {
    /** INTERNAL -- Use n.refersTo(value, _, origin) instead */
    pragma [noinline]
    predicate points_to(ControlFlowNode f, Object value, ControlFlowNode origin) {
    (
            f.isLiteral() and value = f and not f.getNode() instanceof ImmutableLiteral
            or
            f.isFunction() and value = f
        ) and origin = f
    }
}

/** The kwargs parameter (**kwargs) in a function definition is always a dict */
predicate kwargs_points_to(ControlFlowNode f, ClassObject cls) {
    exists(Function func | func.getKwarg() = f.getNode()) and
    cls = theDictType()
}

/** The varargs (*varargs) in a function definition is always a tuple */
predicate varargs_points_to(ControlFlowNode f, ClassObject cls) {
    exists(Function func | func.getVararg() = f.getNode()) and
    cls = theTupleType()
}

/** Gets the class of the object for simple cases, namely constants, functions, 
 * comprehensions and built-in objects.
 *
 *  This exists primarily for internal use. Use getAnInferredType() instead.
 */
pragma [noinline]
ClassObject simple_types(Object obj) {
    result = comprehension(obj.getOrigin())
    or
    result = collection_literal(obj.getOrigin())
    or
    obj.getOrigin() instanceof CallableExpr and result = thePyFunctionType()
    or
    obj.getOrigin() instanceof Module and result = theModuleType()
    or
    result = builtin_object_type(obj)
}

private ClassObject comprehension(Expr e) {
    e instanceof ListComp and result = theListType()
    or
    e instanceof SetComp and result = theSetType()
    or
    e instanceof DictComp and result = theDictType()
    or
    e instanceof GeneratorExp and result = theGeneratorType()
}

private ClassObject collection_literal(Expr e) {
    e instanceof List and result = theListType()
    or
    e instanceof Set and result = theSetType()
    or
    e instanceof Dict and result = theDictType()
    or
    e instanceof Tuple and result = theTupleType()
}

private int tuple_index_value(Object t, int i) {
    result = t.(TupleNode).getElement(i).getNode().(Num).getN().toInt()
    or
    exists(Object item |
         py_citems(t, i, item) and
        result = item.(NumericObject).intValue()
    )
}

pragma [noinline]
int version_tuple_value(Object t) {
    not exists(tuple_index_value(t, 1)) and result = tuple_index_value(t, 0)*10
    or
    not exists(tuple_index_value(t, 2)) and result = tuple_index_value(t, 0)*10 + tuple_index_value(t, 1)
    or
    tuple_index_value(t, 2) = 0 and result = tuple_index_value(t, 0)*10 + tuple_index_value(t, 1)
    or
    tuple_index_value(t, 2) > 0 and result = tuple_index_value(t, 0)*10 + tuple_index_value(t, 1) + 1
}

/** Choose a version numbers that represent the extreme of supported versions. */
private int major_minor() {
    if major_version() = 3 then
        (result = 33 or result = 37)  // 3.3 to 3.7
    else
        (result = 25 or result = 27) // 2.5 to 2.7
}

/** Compares the given tuple object to both the maximum and minimum possible sys.version_info values */
int version_tuple_compare(Object t) {
    version_tuple_value(t) <  major_minor() and result = -1
    or
    version_tuple_value(t) =  major_minor() and result = 0
    or
    version_tuple_value(t) >  major_minor() and result = 1
}

/* Holds if `cls` is a new-style class if it were to have no explicit base classes */
predicate baseless_is_new_style(ClassObject cls) {
    cls.isBuiltin()
    or
    major_version() = 3
    or
    exists(cls.declaredMetaClass())
}

/* The following predicates exist in order to provide
 * more precise type information than the underlying
 * database relations. This help to optimise the points-to
 * analysis.
 */

/** Gets the base class of built-in class `cls` */
pragma [noinline]
ClassObject builtin_base_type(ClassObject cls) {
    /* The extractor uses the special name ".super." to indicate the super class of a builtin class */
    py_cmembers_versioned(cls, ".super.", result, _)
}

/** Gets the `name`d attribute of built-in class `cls` */
pragma [noinline]
Object builtin_class_attribute(ClassObject cls, string name) {
    not name = ".super." and
    py_cmembers_versioned(cls, name, result, _)
}

/** Holds if the `name`d attribute of built-in module `m` is `value` of `cls` */
pragma [noinline]
predicate builtin_module_attribute(ModuleObject m, string name, Object value, ClassObject cls) {
    py_cmembers_versioned(m, name, value, _) and cls = builtin_object_type(value)
}

/** Gets the (built-in) class of the built-in object `obj` */
pragma [noinline]
ClassObject builtin_object_type(Object obj) {
    py_cobjecttypes(obj, result) and not obj = unknownValue()
    or
    obj = unknownValue() and result = theUnknownType()
}

/** Holds if this class (not on a super-class) declares name */
pragma [noinline]
predicate class_declares_attribute(ClassObject cls, string name) {
    exists(Class defn |
        defn = cls.getPyClass() and
        class_defines_name(defn, name)
    )
    or
    exists(Object o |
        o = builtin_class_attribute(cls, name) and 
        not exists(ClassObject sup |
            sup = builtin_base_type(cls) and
            o = builtin_class_attribute(sup, name)
        )
    )
}

/** Holds if the class defines name */
private predicate class_defines_name(Class cls, string name) {
    exists(SsaVariable var | name = var.getId() and var.getAUse() = cls.getANormalExit())
}

/** Gets a return value CFG node, provided that is safe to track across returns */
ControlFlowNode safe_return_node(PyFunctionObject func) {
    result = func.getAReturnedNode()
    // Not a parameter
    and not exists(Parameter p, SsaVariable pvar |
        p.asName().getAFlowNode() = pvar.getDefinition() and
        result = pvar.getAUse()
    ) and
    // No alternatives
    not exists(ControlFlowNode branch | branch.isBranch() and branch.getScope() = func.getFunction())
}

/** Holds if it can be determined from the control flow graph alone that this function can never return */
predicate function_can_never_return(FunctionObject func) {
    /* A Python function never returns if it has no normal exits that are not dominated by a
     * call to a function which itself never returns.
     */
    exists(Function f |
        f = func.getFunction() and
        not exists(f.getAnExitNode())
    )
    or
    func = ModuleObject::named("sys").attr("exit")
}

/** Python specific sub-class of generic EssaNodeDefinition */
class PyNodeDefinition extends EssaNodeDefinition {

    override string getRepresentation() {
        result = this.getAQlClass()
    }

}

/** Python specific sub-class of generic EssaNodeRefinement */
class PyNodeRefinement extends EssaNodeRefinement {

    override string getRepresentation() {
        result = this.getAQlClass() + "(" + this.getInput().getRepresentation() + ")"
        or
        not exists(this.getInput()) and
        result = this.getAQlClass() + "(" + this.getSourceVariable().getName() + "??)"
    }
}

/** An assignment to a variable `v = val` */
class AssignmentDefinition extends PyNodeDefinition {

    AssignmentDefinition() {
        SsaSource::assignment_definition(this.getSourceVariable(), this.getDefiningNode(), _)
    }

    ControlFlowNode getValue() {
        SsaSource::assignment_definition(this.getSourceVariable(), this.getDefiningNode(), result)
    }

    override string getRepresentation() {
        result = this.getValue().getNode().toString()
    }

}

/** Capture of a raised exception `except ExceptionType ex:` */
class ExceptionCapture  extends PyNodeDefinition {

    ExceptionCapture() {
        SsaSource::exception_capture(this.getSourceVariable(), this.getDefiningNode())
    }

    ControlFlowNode getType() {
        exists(ExceptFlowNode ex |
            ex.getName() = this.getDefiningNode() and
            result = ex.getType()
        )
    }

    override string getRepresentation() {
        result = "except " + this.getSourceVariable().getName()
    }

}
/** An assignment to a variable as part of a multiple assignment `..., v, ... = val` */
class MultiAssignmentDefinition extends PyNodeDefinition {

    MultiAssignmentDefinition() {
        SsaSource::multi_assignment_definition(this.getSourceVariable(), this.getDefiningNode())
    }

    override string getRepresentation() {
        result = "..."
    }

}


class WithDefinition extends PyNodeDefinition {

    WithDefinition  () {
        SsaSource::with_definition(this.getSourceVariable(), this.getDefiningNode())
    }

    override string getRepresentation() {
        result = "with"
    }

}

/** A definition of a variable by declaring it as a parameter */
class ParameterDefinition extends PyNodeDefinition {

    ParameterDefinition() {
        SsaSource::parameter_definition(this.getSourceVariable(), this.getDefiningNode())
    }

    predicate isSelf() {
        this.getDefiningNode().getNode().(Parameter).isSelf()
    }

    ControlFlowNode getDefault() {
        result.getNode() = this.getParameter().getDefault()
    }

    Parameter getParameter() {
        result = this.getDefiningNode().getNode()
    }

}

/** A definition of a variable in a for loop `for v in ...:` */
class IterationDefinition extends PyNodeDefinition {

    ControlFlowNode sequence;

    IterationDefinition() {
        SsaSource::iteration_defined_variable(this.getSourceVariable(), this.getDefiningNode(), sequence)
    }

    ControlFlowNode getSequence() {
        result = sequence
    }

}

/** A deletion of a variable `del v` */
class DeletionDefinition extends PyNodeDefinition {

    DeletionDefinition() {
        SsaSource::deletion_definition(this.getSourceVariable(), this.getDefiningNode())
    }

}

/** Definition of variable at the entry of a scope. Usually this represents the transfer of
 * a global or non-local variable from one scope to another.
 */
class ScopeEntryDefinition extends PyNodeDefinition {

    ScopeEntryDefinition() {
        this.getDefiningNode() = this.getSourceVariable().(PythonSsaSourceVariable).getScopeEntryDefinition() and
        not this instanceof ImplicitSubModuleDefinition
    }

    override Scope getScope() {
        result.getEntryNode() = this.getDefiningNode()
    }

}

/** Possible redefinition of variable via `from ... import *` */
class ImportStarRefinement extends PyNodeRefinement {

    ImportStarRefinement() {
        SsaSource::import_star_refinement(this.getSourceVariable(), _, this.getDefiningNode())
    }

}

/** Assignment of an attribute `obj.attr = val` */
class AttributeAssignment extends PyNodeRefinement {

    AttributeAssignment() {
        SsaSource::attribute_assignment_refinement(this.getSourceVariable(), _, this.getDefiningNode())
    }

    string getName() {
        result = this.getDefiningNode().(AttrNode).getName()
    }

    ControlFlowNode getValue() {
        result = this.getDefiningNode().(DefinitionNode).getValue()
    }

    override string getRepresentation() {
        result = this.getAQlClass() + " '" + this.getName() + "'(" + this.getInput().getRepresentation() + ")"
        or
        not exists(this.getInput()) and
        result = this.getAQlClass() + " '" + this.getName() + "'(" + this.getSourceVariable().getName() + "??)"
    }

}

/** A use of a variable as an argument, `foo(v)`, which might modify the object referred to. */
class ArgumentRefinement extends PyNodeRefinement {

    ControlFlowNode argument;

    ArgumentRefinement() {
        SsaSource::argument_refinement(this.getSourceVariable(), argument, this.getDefiningNode())
    }

    ControlFlowNode getArgument() { result = argument }

}

/** Deletion of an attribute `del obj.attr`. */
class EssaAttributeDeletion extends PyNodeRefinement {

    EssaAttributeDeletion() {
        SsaSource::attribute_deletion_refinement(this.getSourceVariable(), _, this.getDefiningNode())
    }

    string getName() {
        result = this.getDefiningNode().(AttrNode).getName()
    }

}

/** A pi-node (guard) with only one successor. */
class SingleSuccessorGuard extends PyNodeRefinement {

    SingleSuccessorGuard() {
        SsaSource::test_refinement(this.getSourceVariable(), _, this.getDefiningNode())
    }

    boolean getSense() {
        exists(this.getDefiningNode().getAFalseSuccessor()) and result = false
        or
        exists(this.getDefiningNode().getATrueSuccessor()) and result = true
    }

    override string getRepresentation() {
        result = PyNodeRefinement.super.getRepresentation() + " [" + this.getSense().toString() + "]"
        or
        not exists(this.getSense()) and
        result = PyNodeRefinement.super.getRepresentation() + " [??]"
    }
}

/** Implicit definition of the names of sub-modules in a package.
 * Although the interpreter does not pre-define these names, merely populating them
 * as they are imported, this is a good approximation for static analysis.
 */
class ImplicitSubModuleDefinition extends PyNodeDefinition {

    ImplicitSubModuleDefinition() {
        SsaSource::init_module_submodule_defn(this.getSourceVariable(), this.getDefiningNode())
    }

}

/** An implicit (possible) definition of an escaping variable at a call-site */
class CallsiteRefinement extends PyNodeRefinement {

    override string toString() {
        result = "CallsiteRefinement"
    }

    CallsiteRefinement() {
        exists(PythonSsaSourceVariable var, ControlFlowNode defn |
            defn = var.redefinedAtCallSite() and
            this.definedBy(var, defn) and
            not this instanceof ArgumentRefinement and
            not this instanceof MethodCallsiteRefinement and
            not this instanceof SingleSuccessorGuard
        )
    }

    CallNode getCall() {
        this.getDefiningNode() = result
    }

}

/** An implicit (possible) modification of the object referred at a method call */
class MethodCallsiteRefinement extends PyNodeRefinement {

    MethodCallsiteRefinement() {
        SsaSource::method_call_refinement(this.getSourceVariable(), _, this.getDefiningNode())
        and not this instanceof SingleSuccessorGuard
    }

    CallNode getCall() {
        this.getDefiningNode() = result
    }

}

/** An implicit (possible) modification of `self` at a method call */
class SelfCallsiteRefinement extends MethodCallsiteRefinement {

    SelfCallsiteRefinement() {
        this.getSourceVariable().(Variable).isSelf()
    }

}

/** Python specific sub-class of generic EssaEdgeRefinement */
class PyEdgeRefinement extends EssaEdgeRefinement {

    override string getRepresentation() {
        /* This is for testing so use capital 'P' to make it sort before 'phi' and
         * be more visually distinctive. */
        result = "Pi(" + this.getInput().getRepresentation() + ") [" + this.getSense() + "]"
        or
        not exists(this.getInput()) and
        result = "Pi(" + this.getSourceVariable().getName() + "??) [" + this.getSense() + "]"
    }

    ControlFlowNode getTest() {
        result = this.getPredecessor().getLastNode()
    }

}

/** Hold if outer contains inner, both are contained within a test and inner is a use is a plain use or an attribute lookup */
pragma[noinline]
predicate contains_interesting_expression_within_test(ControlFlowNode outer, ControlFlowNode inner) {
    inner.isLoad() and
    exists(ControlFlowNode test |
        outer.getAChild*() = inner and
        test_contains(test, outer) and
        test_contains(test, inner) |
        inner instanceof NameNode or
        inner instanceof AttrNode
    )
}

/** Hold if `expr` is a test (a branch) and `use` is within that test */
predicate test_contains(ControlFlowNode expr, ControlFlowNode use) {
    expr.getNode() instanceof Expr and
    expr.isBranch() and
    expr.getAChild*() = use
}

/** Holds if `test` is a test (a branch), `use` is within that test and `def` is an edge from that test with `sense` */
predicate refinement_test(ControlFlowNode test, ControlFlowNode use, boolean sense, PyEdgeRefinement def) {
    /* Because calls such as `len` may create a new variable, we need to go via the source variable
     * That is perfectly safe as we are only dealing with calls that do not mutate their arguments.
     */
    use = def.getInput().getSourceVariable().(Variable).getAUse() and
    test = def.getPredecessor().getLastNode() and
    test_contains(test, use) and
    sense = def.getSense()
}

/** Holds if `f` is an import of the form `from .[...] import name` and the enclosing scope is an __init__ module */
pragma [noinline]
predicate live_import_from_dot_in_init(ImportMemberNode f, EssaVariable var) {
    exists(string name |
        import_from_dot_in_init(f.getModule(name)) and
        var.getSourceVariable().getName() = name and var.getAUse() = f
    )
}

/** Holds if `f` is an import of the form `from .[...] import ...` and the enclosing scope is an __init__ module */
predicate import_from_dot_in_init(ImportExprNode f) {
    f.getScope() = any(Module m).getInitModule() and
    (
        f.getNode().getLevel() = 1 and
        not exists(f.getNode().getName())
        or
        f.getNode().getImportedModuleName() = f.getEnclosingModule().getPackage().getName()
    )
}

/** Gets the pseudo-object representing the value referred to by an undefined variable */
Object undefinedVariable() {
    py_special_objects(result, "_semmle_undefined_value")
}

/** Gets the pseudo-object representing an unknown value */
Object unknownValue() {
    py_special_objects(result, "_1")
}

BuiltinCallable theTypeNewMethod() {
    py_cmembers_versioned(theTypeType(), "__new__", result, major_version().toString())
}

/** Gets the `value, cls, origin` that `f` would refer to if it has not been assigned some other value */
pragma [noinline]
predicate potential_builtin_points_to(NameNode f, Object value, ClassObject cls, ControlFlowNode origin) {
    f.isGlobal() and f.isLoad() and origin = f and
    (
        builtin_name_points_to(f.getId(), value, cls)
        or
        not exists(Object::builtin(f.getId())) and value = unknownValue() and cls = theUnknownType()
    )
}

pragma [noinline]
predicate builtin_name_points_to(string name, Object value, ClassObject cls) {
    value = Object::builtin(name) and py_cobjecttypes(value, cls)
}

module BaseFlow {

    predicate reaches_exit(EssaVariable var) {
        var.getAUse() = var.getScope().getANormalExit()
    }

    /* Helper for this_scope_entry_value_transfer(...). Transfer of values from earlier scope to later on */
    pragma [noinline]
    predicate scope_entry_value_transfer_from_earlier(EssaVariable pred_var, Scope pred_scope, ScopeEntryDefinition succ_def, Scope succ_scope) {
        exists(SsaSourceVariable var |
            reaches_exit(pred_var) and
            pred_var.getScope() = pred_scope and
            var = pred_var.getSourceVariable() and
            var = succ_def.getSourceVariable() and
            succ_def.getScope() = succ_scope
            |
            pred_scope.precedes(succ_scope)
            or
            /* If an `__init__` method does not modify the global variable, then
             * we can skip it and take the value directly from the module.
             */
            exists(Scope init |
                init.getName() = "__init__" and init.precedes(succ_scope) and pred_scope.precedes(init) and
                not var.(Variable).getAStore().getScope() = init and var instanceof GlobalVariable
            )
         )
    }
}

/** Points-to for syntactic elements where context is not relevant */
predicate simple_points_to(ControlFlowNode f, Object value, ClassObject cls, ControlFlowNode origin) {
    kwargs_points_to(f, cls) and value = f and origin = f
    or
    varargs_points_to(f, cls) and value = f and origin = f
    or
    BasePointsTo::points_to(f, value, origin) and cls = simple_types(value)
    or
    value = f.getNode().(ImmutableLiteral).getLiteralObject() and cls = simple_types(value) and origin = f
}

/** Holds if `bit` is a binary expression node with a bitwise operator.
 * Helper for `this_binary_expr_points_to`.
 */
predicate bitwise_expression_node(BinaryExprNode bit, ControlFlowNode left, ControlFlowNode right) {
    exists(Operator op |
        op = bit.getNode().getOp() |
        op instanceof BitAnd or
        op instanceof BitOr or
        op instanceof BitXor
    ) and
    left = bit.getLeft() and
    right = bit.getRight()
}


private
Module theCollectionsAbcModule() {
    result.getName() = "_abcoll"
    or
    result.getName() = "_collections_abc"
}

ClassObject collectionsAbcClass(string name) {
     exists(Class cls |
        result.getPyClass() = cls and
        cls.getName() = name and
        cls.getScope() = theCollectionsAbcModule()
    )
}
