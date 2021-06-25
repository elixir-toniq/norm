# CHANGELOG

## 0.13.0 (June, 25, 2021)

* Bug fix for selections
* Added delegate for recursive schemas

## 0.12.0 (May 12, 2020)

* Added reflection and other improvements to contracts - Wojtek Mach

## 0.11.0 (April 11, 2020)

* Add more primitive generators
* Fix formatting error when selecting unknown keys in a schema
* contracts no longer require predicates to include parens

## 0.10.4 (March 10, 2020)

* [ffe49b3](https://github.com/keathley/norm/commit/ffe49b39dc3cf89c659e91f6958f938b5c6de5c1) Use GitHub CI - Wojtek Mach
* [1fa941b](https://github.com/keathley/norm/commit/1fa941b496463b682b18dcb8c31aedf4e50d5b60) Conform collection values using the correct types - Chris Keathley
* [3313b1e](https://github.com/keathley/norm/commit/3313b1eae8398c2d61daab8d64f7d4af7a522f82) Rearrange Norm's internal AST directory - Chris Keathley
* [e6ae160](https://github.com/keathley/norm/commit/e6ae160f23e382a30edc00e678b4c176025031cd) don't crash if using nested selection with non-map input - Chris Keathley

## 0.10.3 (January 31, 2020)
* [2aa1173](https://github.com/keathley/norm/commit/2aa1173a370d6ba37bca193dc46ef1e302c9216b) Stop selection from duplicating errors with nested schemas - Chris Keathley
* [9ba0261](https://github.com/keathley/norm/commit/9ba0261e91b200fd6807b64e820c4b7490fbc2eb) Merge branch 'return-single-error-from-selection' - Chris Keathley
* [f58631b](https://github.com/keathley/norm/commit/f58631beda926762a01c4e2d995b2d621ecb66a3) Implement inspect for the other structs in Norm - Chris Keathley
* [0997e06](https://github.com/keathley/norm/commit/0997e06edd259eae5267abc806fb1a0d59bc087e) Merge branch 'implement-inspect' - Chris Keathley
* [3f88509](https://github.com/keathley/norm/commit/3f8850912dc07ed06895e36d3419af1e77ef23a8) Allow ellision of parens on single arity functions - Chris Keathley
* [5be61af](https://github.com/keathley/norm/commit/5be61afc8f5b47297685bf3dcbc8e9bece0b494d) Merge branch 'allow-predicates-without-parens' - Chris Keathley
* [6bf487d](https://github.com/keathley/norm/commit/6bf487de2151fdb61c62210e22cefd4a96a41ea9) Return errors from selections correctly - Chris Keathley
* [6a5c8b2](https://github.com/keathley/norm/commit/6a5c8b2bc97d49b406b68074406dd205211c21f3) Merge branch 'error-if-selection-specifies-key-not-in-schema' - Chris Keathley
* [31ad460](https://github.com/keathley/norm/commit/31ad460710d88d01189188d1f38b78700891362c) Allow structs to conform with default keys - Chris Keathley
* [ee46655](https://github.com/keathley/norm/commit/ee466552e423d083a1ae2ffef7d114e56038040f) Merge branch 'allow-struct-schemas-to-use-defaults' - Chris Keathley
* [1c950e1](https://github.com/keathley/norm/commit/1c950e1aac7d510c67ca712a97e0e2bf521419b9) Always return selection errors - Chris Keathley
* [f99a122](https://github.com/keathley/norm/commit/f99a1229f8c109ee16493aa48f319287725f13f0) Merge branch 'always-return-selection-errors' - Chris Keathley

## 0.10.2 (January 20, 2020)

* [1a5e6ce](https://github.com/keathley/norm/commit/1a5e6ce7b0ace069342885e71b9fdfffd0fe0ee6) Handle selections around structs with nested maps - Chris Keathley
* [dc32fab](https://github.com/keathley/norm/commit/dc32fab3adade4a5b3b6ab76dbc9d2a9d84b1d13) Merge branch 'selection-on-structs' - Chris Keathley

## 0.10.1 (January 14, 2020)

* [45c05a0](https://github.com/keathley/norm/commit/45c05a003b0aa213b2e15803fa3130bc59a7c869) Don't raise exceptions when trying to conform tuples - Chris Keathley
* [2d50cd7](https://github.com/keathley/norm/commit/2d50cd7f869eb63637b103e3ef378080c2571c18) Merge branch 'fix-exception-in-tuple-conformer' - Chris Keathley

## 0.10.0 (December 30, 2019)

* [28105e6](https://github.com/keathley/norm/commit/28105e6d77245e9d21221028f25f860ab413e597) Contracts - Wojtek Mach
* [02221e6](https://github.com/keathley/norm/commit/02221e6a1f02cc15177df651591fff8e96089fc4) Add docs about contracts to README - Chris Keathley

## 0.9.2 (December 09, 2019)

* [cc9ea68](https://github.com/keathley/norm/commit/cc9ea6856ba9a08402d6077f749348d61c247565) Don't flatten good results - Chris Keathley

## 0.9.1 (December 03, 2019)

* [52dbe8a](https://github.com/keathley/norm/commit/52dbe8a19906c4d32311d09fbc666fccb0b45d2e) Conform struct input with map schemas

## 0.9.0 (December 02, 2019)

* [fe5fc68](https://github.com/keathley/norm/commit/fe5fc682bb9b4fd1ce03c9068303751193c33cdb) Changes to optionality in schema's and selection

## 0.8.1 (November 24, 2019)

* [41bff7a](https://github.com/keathley/norm/commit/41bff7a4af1296bc16eff298249f01546fcf245d) Add Credo Support - Joey Rosztoczy
* [7f2773f](https://github.com/keathley/norm/commit/7f2773fd4fb488a9a4c0a42c9bf3a7bf689eda55) Doc fixes - Brett Wise
* [8880dd5](https://github.com/keathley/norm/commit/8880dd590dc798aa306c19b8bcef4a0514bad498) Doc fixes - Kevin Baird
* [172edad](https://github.com/keathley/norm/commit/172edad05070f7d997fdb3dcfb43f1978188039c) `coll_of` and `map_of` fixes - Stefan Fochler
