import javascript

from DataFlow::Portal p, boolean isUserControlled
select p, p.getAnExitNode(isUserControlled), isUserControlled
