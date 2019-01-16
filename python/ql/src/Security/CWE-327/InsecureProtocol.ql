/**
 * @name Use of insecure SSL/TLS version
 * @description Using an insecure SSL/TLS version may leave the connection vulnerable to attacks.
 * @id py/insecure-protocol
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags security
 *       external/cwe/cwe-327
 */

import python

FunctionObject ssl_wrap_socket() {
    result = the_ssl_module().getAttribute("wrap_socket")
}

ClassObject ssl_Context_class() {
    result = the_ssl_module().getAttribute("SSLContext")
}

string insecure_version_name() {
    // For `pyOpenSSL.SSL`
    result = "SSLv2_METHOD" or
    result = "SSLv23_METHOD" or
    result = "SSLv3_METHOD" or
    result = "TLSv1_METHOD" or
    // For the `ssl` module
    result = "PROTOCOL_SSLv2" or
    result = "PROTOCOL_SSLv3" or
    result = "PROTOCOL_SSLv23" or
    result = "PROTOCOL_TLS" or
    result = "PROTOCOL_TLSv1"
}

private ModuleObject the_ssl_module() {
    result = any(ModuleObject m | m.getName() = "ssl")
}

private ModuleObject the_pyOpenSSL_module() {
    result = any(ModuleObject m | m.getName() = "pyOpenSSL.SSL")
}

/* A syntactic check for cases where points-to analysis cannot infer the presence of
 * a protocol constant, e.g. if it has been removed in later versions of the `ssl`
 * library.
 */
predicate probable_insecure_ssl_constant(CallNode call, string insecure_version) {
    exists(ControlFlowNode arg | arg = call.getArgByName("ssl_version") |
        arg.(AttrNode).getObject(insecure_version).refersTo(the_ssl_module())
        or
        arg.(NameNode).getId() = insecure_version and
        exists(Import imp |
            imp.getAnImportedModuleName() = "ssl" and
            imp.getAName().getAsname().(Name).getId() = insecure_version
        )
    )
}

predicate unsafe_ssl_wrap_socket_call(CallNode call, string method_name, string insecure_version) {
    (
        call = ssl_wrap_socket().getACall() and
        method_name = "deprecated method ssl.wrap_socket"
        or
        call = ssl_Context_class().getACall() and
        method_name = "ssl.SSLContext"
    )
    and
    insecure_version = insecure_version_name()
    and
    (
        call.getArgByName("ssl_version").refersTo(the_ssl_module().getAttribute(insecure_version))
        or
        probable_insecure_ssl_constant(call, insecure_version)
    )
}

ClassObject the_pyOpenSSL_Context_class() {
    result = any(ModuleObject m | m.getName() = "pyOpenSSL.SSL").getAttribute("Context")
}

predicate unsafe_pyOpenSSL_Context_call(CallNode call, string insecure_version) {
    call = the_pyOpenSSL_Context_class().getACall() and
    insecure_version = insecure_version_name() and
    call.getArg(0).refersTo(the_pyOpenSSL_module().getAttribute(insecure_version))
}

from CallNode call, string method_name, string insecure_version
where
    unsafe_ssl_wrap_socket_call(call, method_name, insecure_version)
or
    unsafe_pyOpenSSL_Context_call(call, insecure_version) and method_name = "pyOpenSSL.SSL.Context"
select call, "Insecure SSL/TLS protocol version " + insecure_version + " specified in call to " + method_name + "."