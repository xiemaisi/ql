/**
 * @name Typo for exponentiation operator
 * @description Using the bitwise-exclusive-or operator `^` instead of the exponentiation operator
 *              `**` leads to wrong results.
 * @kind problem
 * @problem.severity warning
 * @id js/exponentiation-typo
 * @tags correctness
 * @precision high
 */

import javascript

/** Holds if `e` is a binary, octal or hexadecimal integer literal, or the number one. */
predicate maybeBitPattern(Expr e) {
  e.(NumberLiteral).getRawValue().regexpMatch("(?i)0[box].+|0[0-7]+")
  or
  e.getIntValue() = 1
}

from XOrExpr x, int l, int r
where
  // both sides are positive integer constants
  l = x.getLeftOperand().getIntValue() and l > 0 and
  r = x.getRightOperand().getIntValue() and r > 0 and
  // but neither looks like a bit pattern
  not maybeBitPattern(x.getAnOperand())
select x, "Possible typo for " + l + " ** " + r + "."
