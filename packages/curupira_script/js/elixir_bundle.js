// No runtime imports needed

export default {
  "Fixtures.Simple": {
    hello: function() {
        return 'world';
    }
},
  "Fixtures.WithArgs": {
    greet: function(name) {
        return 'Hello, ' + name + '!';
    }
}
};

