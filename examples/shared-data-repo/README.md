# Shared data repository as a submodule (example)

> Example folder from [claude-code-guide](https://github.com/alopezespino/claude-code-guide): one repository builds a data baseline that several projects use, and each project adds it as a git submodule and filters it further for its own needs.

Use this when several projects start from the same cleaned data or the same pipeline, and their results depend on the exact version of it. The shared repository holds the code that builds the baseline and the one function projects call to read it. Each project adds the shared repository as a git submodule, so the project records the exact commit it used, and keeps its own filters and analysis in its own code.

This differs from a shared script kept in sync by copying ([`examples/coordination/`](../coordination/)): a copied script is small, runs on its own and every project should have the latest version. A shared data repository is pinned per project, because moving to a newer version changes the project's results and should happen deliberately, with a rerun and a commit that says why.

```text
shared-data-repo/
├── base-data/                     the shared repository (its own git repo)
│   ├── build/build_baseline.R     builds the baseline once (here from made-up data)
│   └── R/baseline.R               read_baseline(): the one entry point projects use
└── paper-a/                       a project that uses it
    └── code/1_sample.R            reads the baseline through the submodule, applies its own filter
```

In a real setup `base-data` and `paper-a` are separate repositories, and `base-data` sits inside `paper-a` as the submodule folder `paper-a/base-data`. Here they are side by side so the example runs without a remote.

## Try it

```bash
cd examples/shared-data-repo/base-data
Rscript build/build_baseline.R
cd ../paper-a
BASE_DATA_DIR=../base-data Rscript code/1_sample.R
```

The first script writes `base-data/output/baseline.csv` and a fingerprint (row count and commit). The second reads the baseline through `read_baseline()`, which stops if the table does not match its fingerprint, keeps one sector and the later years, and logs the baseline commit it used. Outputs are ignored by git.

## Set it up with real repositories

Once, for the shared repository: create it, push it to its remote, and document in its README where the raw data live (data files are never committed; large or confidential inputs stay where they are stored, and the repository holds only code and paths).

In each project that uses it:

```bash
git submodule add <shared repo URL> base-data
git commit -m "base-data: add the shared baseline at its current commit"
```

A collaborator who clones the project gets the same version of the shared code:

```bash
git clone --recurse-submodules <project repo URL>
# or, after a plain clone:
git submodule update --init
```

## Day to day

- **Take a newer version on purpose.** `git submodule update --remote base-data`, rerun the project's pipeline, compare the results, then `git add base-data` and commit with the reason (`base-data: bump to <commit>, fixes duplicate units`). Until then the project keeps the version it recorded.
- **Fix the shared code in the shared repository.** A fix to the baseline is made once, in `base-data` (a branch there, pushed to its remote), and reaches each project when that project bumps its submodule. Never patch a project's copy of the submodule without pushing the change back: it would exist in one project only.
- **Keep project-specific work out of the shared repository.** Filters, samples, variables only one paper needs and its analysis live in the project. The shared repository holds what every project agrees on.
- **Record the version in the outputs.** The fingerprint carries the commit the baseline was built from, and each project logs it next to its own results, so any table can be traced to the baseline that produced it.
- **Build once where the data live.** When the baseline is large, build it on the machine that holds the raw data (a server or a cluster) and point `BASE_DATA_OUT` to a shared folder there; projects read it from that path.
