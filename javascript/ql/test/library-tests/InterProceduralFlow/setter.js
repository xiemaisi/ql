class A {
  setX(v) { this.x = v; }
  getX() { return this.x; }
}

var source = "tainted";
var a1 = new A(), a2 = new A();

a1.setX(source);
var sink1 = a1.x;
var sink2 = a1.getX();

a2.setX("not tainted");
var sink3 = a2.x;
var sink4 = a2.getX();

// semmle-extractor-options: --source-type module
