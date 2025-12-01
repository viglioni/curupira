import Fixtures from './elixir_bundle.js';

console.log('Testing nested bundle...');
console.log('Fixtures:', Fixtures);
console.log('Fixtures.Simple:', Fixtures.Simple);
console.log('Fixtures.Simple.hello():', Fixtures.Simple.hello());
console.log('Fixtures.WithArgs.greet("World"):', Fixtures.WithArgs.greet("World"));
