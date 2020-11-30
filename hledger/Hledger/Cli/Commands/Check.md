check\
Check for various kinds of errors in your data.

_FLAGS

hledger provides a number of built-in error checks to help
prevent problems in your data. Some, but not all, of these are run
automatically before all commands. You can also use this `check`
command to run any of the available tests. They are named, 
and run, as follows:

`hledger check` runs the basic checks, like all other commands,
but with no output unless there is a problem. These are:

- **parseable** - data files are well-formed and can be [successfully parsed](hledger.html#input-files)
- **autobalanced** - all transactions are [balanced](journal.html#postings), inferring missing amounts where necessary, and possibly converting commodities using [transaction prices] or automatically-inferred transaction prices
- **assertions** - all [balance assertions] are passing (except with `-I`/`--ignore-assertions`)

[transaction prices]: journal.html#transaction-prices
[balance assertions]: journal.html#balance-assertions
[strict mode]: hledger.html#strict-mode

`hledger check --strict` also runs the additional "strict mode" checks,
which are:

- **accounts** - all account names used by transactions [have been declared](journal.html#account-error-checking)
- **commodities** - all commodity symbols used [have been declared](journal.html#commodity-error-checking)

`hledger check CHECK1 CHECK2 ...` runs all of the named checks, in turn. 
This may be useful when neither the default nor strict checks are exactly
what you want, or when you want to focus on a single check of interest. 
The arguments are standard lowercase names for the checks. Currently
only these checks can be run in this way:

- **dates** - transactions are ordered by date (similar to the old `check-dates` command)
- **leafnames** - all account leaf names are unique ((similar to the old `check-dupes` command)

See also: 

Some checks are shipped as addon scripts for now
(cf <https://github.com/simonmichael/hledger/tree/master/bin>, and Cookbook -> [Scripting](scripting.html)):

- **tagfiles** - all tag values containing / (a forward slash) exist as file paths
- **fancyassertions** - more complex balance assertions are passing