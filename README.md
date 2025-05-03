
# Deploy
```bash
forge script ./script/basic_deploy.sol --rpc-url "http://localhost:8545" --broadcast 
```

# Coverage
```bash
forge coverage --report lcov --report-file lcov.info
```

```bash
genhtml lcov.info --output-directory coverage-report
```