# Do/Avoid iOS development and visual review

- Develop and verify on the iOS Simulator. Use actual SwiftUI screenshots and include a narrow viewport when layout matters.
- Store evidence under `docs/design/<feature-or-milestone>/`. Include a README describing the implementation, tested source commit, verification results, and known limitations. Use `field.png` for the main Field screenshot and descriptive filenames for other affected screens or states.
- Before owner review, run the relevant tests, build both production and Dev, inspect the simulator captures, fix defects, and repeat verification after corrections. Commit and push code and evidence together.
- Use reproducible histories for new items, established habits, setbacks, recovery, and transitions. Clearly distinguish Progression Lab experiments from the shipping behavior.
- Keep app identity and stored data intact. Once simulator verification is complete, use `./scripts/install-dev-iphone.sh` to update the existing Personal Team install in place. Use the owner’s phone for device-specific validation. Request a phone screenshot only when investigating behavior that cannot be reproduced in the simulator.
- Report the exact commit SHA, test and build results, direct GitHub evidence links, known limitations, and whether the candidate is ready for physical-device testing.
