function App() {
  var foo = this.foo;
  var bar = this.bar;
}

App.prototype = {
  foo: function() {
    console.log("Hai, this is foo.");
  }
};

App.prototype.bar = function() {
  console.log("And this is bar.");
};
