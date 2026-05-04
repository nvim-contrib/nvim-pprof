# Changelog

## [0.5.2](https://github.com/nvim-contrib/nvim-pprof/compare/v0.5.1...v0.5.2) (2026-05-04)


### Bug Fixes

* **github:** correct action versions in update.yml ([8c57cb7](https://github.com/nvim-contrib/nvim-pprof/commit/8c57cb7c163df006d6e12214db6091f47bf18f6d))

## [0.5.1](https://github.com/nvim-contrib/nvim-pprof/compare/v0.5.0...v0.5.1) (2026-04-22)


### Bug Fixes

* **neotest:** defer picker to after other consumers run ([98437bb](https://github.com/nvim-contrib/nvim-pprof/commit/98437bb371f3612ba90a016693eec4d463f95722))

## [0.5.0](https://github.com/nvim-contrib/nvim-pprof/compare/v0.4.1...v0.5.0) (2026-04-22)


### Features

* add silent mode and improve profile file discovery ([4c17a34](https://github.com/nvim-contrib/nvim-pprof/commit/4c17a34b29fd838df02ddbbee9550328633a026e))
* support string[] in load() and simplify neotest/go consumer ([7cfa9d3](https://github.com/nvim-contrib/nvim-pprof/commit/7cfa9d30a932f3dd9eb244acb1f955d29ab72f56))


### Bug Fixes

* **neotest/go:** handle empty profile results ([463ccc3](https://github.com/nvim-contrib/nvim-pprof/commit/463ccc33801cbb9e8a2ea8d0f5ff162e858247f7))

## [0.4.1](https://github.com/nvim-contrib/nvim-pprof/compare/v0.4.0...v0.4.1) (2026-04-16)


### Bug Fixes

* add postCreateCommand to restore nix volume permissions ([ad60359](https://github.com/nvim-contrib/nvim-pprof/commit/ad603594ddf4f4679e71c4277325b72ddbee1d0b))

## [0.4.0](https://github.com/nvim-contrib/nvim-pprof/compare/v0.3.0...v0.4.0) (2026-03-23)


### Features

* add PProfBrowser and PProfBrowserStop commands ([261e2d7](https://github.com/nvim-contrib/nvim-pprof/commit/261e2d7c4a199373185d51480bab5c6d6c50872c))
* PProfServerStart auto-loads profile if not already cached ([078014c](https://github.com/nvim-contrib/nvim-pprof/commit/078014cd4a33c44a91e0b4f83066405f12cdc731))

## [0.3.0](https://github.com/nvim-contrib/nvim-pprof/compare/v0.2.0...v0.3.0) (2026-03-22)


### Features

* add config.file for profile auto-discovery patterns ([a6052f5](https://github.com/nvim-contrib/nvim-pprof/commit/a6052f55737db1a23b0cf7119ef4c1035a2303f3))
* add neotest consumers (generic + Go-specific) ([cf40aa2](https://github.com/nvim-contrib/nvim-pprof/commit/cf40aa2ea7d4254d93b1880e2c2edfb83f192359))
* **top:** heat-color data rows by flat_pct; fix jump_to_func for new column order ([055612a](https://github.com/nvim-contrib/nvim-pprof/commit/055612a942076b8c0789cf7d2b1580d87fa1d67d))
* **top:** min_flat_pct threshold + pass/fail column highlight; restructure à la nvim-coverage ([366b5e8](https://github.com/nvim-contrib/nvim-pprof/commit/366b5e8c8fbd2362d6fe2d199e70b380392fa45d))
* **top:** sparkline bar + profile type in top window ([905b7ed](https://github.com/nvim-contrib/nvim-pprof/commit/905b7edd982f1831dc66d4e613460888267e43c6))


### Bug Fixes

* **tests:** align config_spec assertions with refactored config paths ([a70e8b3](https://github.com/nvim-contrib/nvim-pprof/commit/a70e8b34a0c67acb82c46ec19d4d2e5fc8e41b55))
* **top:** put function name first, numbers after (like nvim-coverage report) ([9949957](https://github.com/nvim-contrib/nvim-pprof/commit/99499573bd208db2cec5dbdd8ab417938df01774))

## [0.2.0](https://github.com/nvim-contrib/nvim-pprof/compare/v0.1.0...v0.2.0) (2026-03-21)


### Features

* initial implementation of nvim-pprof ([32efde3](https://github.com/nvim-contrib/nvim-pprof/commit/32efde34940cb8a7a7a69786ed9379db7d47ced1))
