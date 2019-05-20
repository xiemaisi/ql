define([
        'a.js',      // not resolved: ambiguous
        'foo',       // not resolved: too short for positive identification
        'nested/a',  // resolved to `lib/nested/a.js`
        'lib/foo.js' // resolved to `lib/foo.js`
       ], function(a, b, exports) {
    return {
        foo: a.foo,
        bar: b.bar
    };
});