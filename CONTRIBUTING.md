# Contributing to Zarko

Hey Ziguana, thanks for taking the time to contribute to **Zarko**! 🦎

All types of contributions are encouraged and valued. Whether you're fixing a bug, improving documentation, suggesting an enhancement, or contributing code, we appreciate your help.

Please read the relevant section below before contributing. It will make the process smoother for both contributors and maintainers.

## Table of Contents

- [I Have a Question](#i-have-a-question)

- [I Want to Contribute](#i-want-to-contribute)

  - [Legal Notice](#legal-notice)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Improving the Documentation](#improving-the-documentation)

- [Styleguides](#styleguides)

  - [Code Style](#code-style)
  - [Commit Messages](#commit-messages)
  - [Pull Requests](#pull-requests)

- [Join the Project Team](#join-the-project-team)

- [Attribution](#attribution)

## I Have a Question

> If you want to ask a question, we assume that you have read the available documentation first.

Before asking a question, please check the existing [Issues](https://github.com/TynK-M/zarko/issues) to see whether someone has already encountered the same problem.

You should also search the internet for answers first, especially if your question concerns a dependency, operating system, development environment, or general programming topic.

If you still need help:

1. Open a [new issue](https://github.com/TynK-M/zarko/issues/new).
1. Clearly explain what you're trying to accomplish.
1. Provide as much relevant context as possible.
1. Include the Zarko version, environment, and platform where applicable.
1. Include relevant logs, error messages, or examples.

Please avoid opening issues for questions that can be answered by reading the documentation or existing project discussions.

## I Want to Contribute

There are many ways to contribute to Zarko:

- Report bugs.
- Suggest new features or improvements.
- Submit code changes.
- Improve documentation.
- Improve tests.
- Review pull requests.
- Help other contributors and users.

### Legal Notice

By contributing to Zarko, you confirm that:

- You have authored the content you are contributing, or have the necessary rights to contribute it.
- You have the right to submit the contribution under the project's license.
- Your contribution may be distributed as part of Zarko under the project's license.

Please do not submit code, documentation, images, or other material that you do not have permission to redistribute.

## Reporting Bugs

### Before Submitting a Bug Report

A good bug report should contain enough information for someone else to understand and reproduce the problem without having to chase you for additional details.

Before submitting a report:

- Make sure you are using the latest version of Zarko.
- Read the relevant documentation.
- Check the existing [issues](https://github.com/TynK-M/zarko/issues).
- Search the [bug reports](https://github.com/TynK-M/zarko/issues?q=label%3Abug) for similar problems.
- Search the internet, including Stack Overflow, for related issues.
- Verify that the problem is caused by Zarko rather than an incompatible environment or configuration.

When possible, collect the following information:

- A complete error message or stack trace.
- Operating system and version.
- Platform and architecture, such as x86, x64, ARM, etc.
- Zarko version.
- Compiler, runtime, package manager, or dependency versions relevant to the issue.
- Relevant configuration.
- The input that caused the problem.
- The output you expected.
- The output you actually received.
- Whether the issue can be reproduced reliably.
- Whether the issue also occurs with previous versions.

### How Do I Submit a Good Bug Report?

Bug reports are tracked through [GitHub Issues](https://github.com/TynK-M/zarko/issues).

When submitting an issue:

1. Open a [new issue](https://github.com/TynK-M/zarko/issues/new).
1. Clearly describe what you expected to happen.
1. Clearly describe what actually happened.
1. Provide detailed steps to reproduce the problem.
1. Include a minimal reproducible example whenever possible.
1. Include the environment and version information collected above.
1. Include relevant logs or stack traces.

Please avoid vague reports such as:

> It doesn't work.

Instead, explain exactly what you did, what happened, and what you expected to happen.

Once an issue has been filed:

- A maintainer may add appropriate labels.
- A maintainer may ask for additional information.
- Issues that cannot be reproduced may be marked as needing reproduction information.
- Reproducible bugs may be prioritized for a fix.
- Maintainers may ask contributors to submit a pull request if they would like to implement the fix themselves.

## Suggesting Enhancements

Enhancement suggestions are welcome, including:

- Completely new features.
- Improvements to existing functionality.
- Developer experience improvements.
- Performance improvements.
- Documentation improvements.
- Better error messages.
- Testing improvements.

### Before Submitting an Enhancement

Before opening an enhancement issue:

- Make sure you are using the latest version of Zarko.
- Read the documentation carefully.
- Check whether the functionality already exists through configuration or another supported approach.
- Search [existing issues](https://github.com/TynK-M/zarko/issues) for similar suggestions.
- Consider whether the idea fits Zarko's goals and scope.
- Think about whether the proposed feature would benefit a broad range of users.

If your idea is primarily useful to a small group of users, consider whether it would be better implemented as an extension, plugin, or separate project.

### How Do I Submit a Good Enhancement Suggestion?

Enhancement suggestions are tracked through [GitHub Issues](https://github.com/TynK-M/zarko/issues).

A good enhancement request should include:

- A clear and descriptive title.
- A detailed explanation of the proposed feature.
- The current behavior.
- The behavior you would like to see instead.
- Why the change would be useful.
- Examples of how the feature could be used.
- Alternatives you have considered.
- Links to relevant projects or implementations, if applicable.

The more concrete your proposal is, the easier it is for maintainers and contributors to evaluate.

## Your First Code Contribution

New contributors are welcome!

If you'd like to contribute code:

1. Fork the repository.
1. Clone your fork locally.
1. Create a new branch for your change.
1. Make your changes.
1. Add or update tests where appropriate.
1. Run the project's existing checks and test suite.
1. Review your changes before committing.
1. Commit your changes using the project's commit message conventions.
1. Push your branch to your fork.
1. Open a pull request against the Zarko repository.

Try to keep each pull request focused on a single change. Small, focused pull requests are easier to review, test, and merge.

If you're unsure where to start, look through the existing issues for tasks that are suitable for contributors.

## Improving the Documentation

Documentation improvements are just as valuable as code contributions.

You can help by:

- Fixing spelling or grammar mistakes.
- Clarifying confusing explanations.
- Adding missing examples.
- Improving installation instructions.
- Documenting configuration options.
- Adding troubleshooting information.
- Updating outdated documentation.
- Improving API or developer documentation.

When changing documentation, keep explanations concise, accurate, and easy for new users to understand.

If your documentation change describes behavior that has also changed in the code, please update the relevant code and tests as well.

## Styleguides

### Code Style

Follow the existing style and conventions used throughout the Zarko codebase.

When contributing code:

- Prefer clear and readable implementations.
- Keep functions and modules focused.
- Avoid unnecessary complexity.
- Reuse existing utilities and abstractions where appropriate.
- Add comments when they explain *why* something is done, rather than simply describing *what* the code does.
- Keep changes consistent with surrounding code.

Before opening a pull request, run the formatting, linting, and test commands documented by the project.

### Commit Messages

Zarko follows a Conventional Commits-style format for commit messages.

Use the following structure

```text
type(scope): short description

Optional longer description explaining what changed and why.
```

The first line should be concise and describe the change in the imperative mood where practical.

Common commit types include:

- `feat`, introduce a new feature or functionality.
- `fix`, fix a bug or incorrect behavior.
- `ref`, restructure code without changing its behavior.
- `test`, add or update tests.
- `chore`, maintenance changes that don't affect functionality (documentation included).
- `build`, change build configuration.

The scope should identify the part of Zarko affected by the change.

For example:

```text
feat(record): introduce CSV record abstraction with field access helpers

Adds a lightweight record representation for parsed CSV rows
```

Avoid vague messages such as:

```text
fix stuff
changes
update
oops
```

### Pull Requests

Before opening a pull request:

- Make sure your branch is up to date with the target branch where appropriate.
- Make sure the project builds successfully.
- Run the available tests.
- Run formatting and linting checks.
- Review the diff for accidental changes.
- Update documentation when necessary.
- Add tests for bug fixes and new behavior when appropriate.

A good pull request should:

- Have a clear title.
- Explain what was changed.
- Explain why the change was necessary.
- Include relevant issue numbers where applicable.
- Include screenshots, logs, or examples when they help explain the change.
- Keep unrelated changes out of the pull request.

Maintainers may request changes before a pull request is merged. Please treat review feedback as part of the collaborative development process.

## Join the Project Team

Interested in becoming more involved with Zarko?

Start by contributing regularly through issues, pull requests, documentation, testing, or community support.

Contributors who consistently demonstrate good judgment, technical ability, and a willingness to collaborate may be invited to take on additional responsibilities within the project.

There is no requirement to be an expert before contributing. Everyone starts somewhere, and we appreciate contributors who help make Zarko better for the whole community.

## Supporting Zarko

If you like Zarko but don't have time to contribute code, there are other ways to support the project:

- Star the project.
- Share Zarko with others.
- Mention Zarko in your project's README.
- Talk about Zarko at local meetups or in your community.
- Tell friends and colleagues who may find the project useful.
- Report issues when you encounter them.
- Help improve the documentation.

Every bit of support helps.

## Attribution

This contributing guide is inspired by the [contributing.md](https://contributing.md/generator) project and has been adapted for Zarko.

Thank you for contributing to Zarko! 🦎
