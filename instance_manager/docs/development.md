# 🧪 Development Setup

To get the best development experience—especially with IDE autocompletion, type checking, and linting—follow these steps:

## 1. Install dependencies

We use Poetry for package management. Run:

```bash
poetry install
# To install dev dependencies like type hints and linting tools:
poetry install --with dev
# Alternatively:
poetry add --dev boto3-stubs[ec2,autoscaling] mypy
```

## 2. Configure your IDE (VS Code recommended)

Make sure the .vscode/settings.json file exists with this config:

```json
{
  "python.analysis.stubPaths": [
    "./typings"
  ],
  "python.analysis.typeCheckingMode": "basic"
}
```

This enables features like:

- IntelliSense for AWS clients (e.g., EC2, Auto Scaling)
- Type safety via mypy
- Improved code navigation

## 3. Optional: Run type checks manually

```bash
poetry run mypy src/
```
