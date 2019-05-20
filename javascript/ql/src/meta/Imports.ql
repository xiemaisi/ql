/**
 * @name Import resolution
 * @description Helper query that computes the targets of all imports.
 * @kind problem
 * @problem.severity recommendation
 * @precision very-high
 * @id js/import-resolution
 */

import javascript

from Import i, Module m
where i.getImportedModule() = m
select i, "This import resolves to $@.", m, m.getName()
