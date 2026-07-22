# Legacy RPG Service Program Example
### Fixed-Format RPG | ILE Architecture | NOMAIN Module | Date Utility Service

A complete IBM i legacy fixed-format RPG service program example demonstrating 
the ILE architecture patterns used in production shops throughout the AS/400 and 
early IBM i era. Shows how reusable utility procedures were packaged into service 
programs before modern free-format RPG was available.

This example pairs with the [Modern ILE Service Program Example](../ILE-ServiceProgram-Example) 
to show the same architectural concepts in both legacy fixed-format and modern 
free-format styles.

---

## Files

| File | Type | Description |
|---|---|---|
| `UTILMOD.RPGLE` | RPG Module | Date formatting utility — FormatDate procedure |
| `UTILSRV.BND` | Binder Source | Export definitions and V1 signature |
| `EMPMOD.RPGLE` | RPG Module | Employee salary update — calls FormatDate |
| `TESTFMT.RPGLE` | RPG *PGM | Test driver — exercises FormatDate with known dates |

---

## What This Demonstrates

```
UTILMOD.RPGLE      ← utility module (FormatDate procedure)
    ↓ exported via
UTILSRV.BND        ← binder source (the contract)
    ↓ compiled into
UTILSRV (*SRVPGM)  ← reusable service program
    ↓ called by
EMPMOD.RPGLE       ← business program (updates employee salary)
TESTFMT.RPGLE      ← test driver (verifies FormatDate output)
```

---

## UTILMOD — Date Formatting Utility

Provides a single exported procedure `FormatDate` that converts an IBM i native 
date field to a formatted character string in three international formats.

### H NOMAIN — The Critical Keyword

```rpgle
H NOMAIN
```

`NOMAIN` tells the compiler this module has **no main entry point** — it is a 
pure collection of procedures, not a runnable program. Without this keyword the 
compiler expects a traditional mainline calculation section and generates 
unnecessary cycle overhead. Every service program module should use `NOMAIN`.

### FormatDate Procedure

```rpgle
PFormatDate       B                   EXPORT
DFormatDate       PI            10A
DpDate                            D   DATFMT(*ISO)
DpFormat                         3A   CONST
```

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `pDate` | Date (ISO) | Input date — any IBM i date field |
| `pFormat` | CHAR(3) CONST | Format code — see table below |

**Return value:** CHAR(10) — formatted date string

**Format codes:**

| Code | Format | Example |
|---|---|---|
| `'US '` | MM/DD/YYYY | 03/15/2018 |
| `'EUR'` | DD.MM.YYYY | 15.03.2018 |
| `'ISO'` | YYYY-MM-DD | 2018-03-15 (default) |

**Note:** `'US '` has a trailing space — the format parameter is CHAR(3) so 
the two-character code needs padding to fill the field. A common mistake is 
passing `'US'` without the space which falls through to the ISO default.

### Leading Zero Handling — Legacy Pattern

The procedure manually builds leading zeros for single-digit months and days:

```rpgle
C                   IF        wMonthNum < 10
C                   EVAL      wMonth = '0' + %TRIM(%CHAR(wMonthNum))
C                   ELSE
C                   EVAL      wMonth = %CHAR(wMonthNum)
C                   ENDIF
```

**Modern free-format equivalent** — same result, much cleaner:

```rpgle
// Modern approach using %CHAR with edit code
wMonth = %subst(%editc(wMonthNum:'X'):1:2);

// Or using built-in date formatting
wResult = %char(pDate:*USA);   // returns MM/DD/YYYY directly
```

The legacy manual approach is educational — it shows how developers solved 
formatting problems before modern BIFs were available.

### Prototype Declaration

In this example the prototype is declared **inside each calling program**:

```rpgle
// Declared in EMPMOD and TESTFMT individually:
D FormatDate      PR            10A
D  pDate                          D   DATFMT(*ISO)
D  pFormat                       3A   CONST
```

**Production best practice** — a separate prototype header copy book:

```rpgle
// UTILSRVH — copy book (not included in this example)
// Each calling program would use:
/copy MYLIB/QRPGLESRC,UTILSRVH
```

A dedicated copy book means if `FormatDate` gains a new parameter you update 
one file and recompile all callers — rather than finding every inline declaration. 
The inline approach works for simple examples but doesn't scale in production shops 
with many programs calling the same service program.

---

## UTILSRV.BND — Binder Source

```
STRPGMEXP PGMLVL(*CURRENT) SIGNATURE('UTILSRV_V1')
  EXPORT SYMBOL('FormatDate')
ENDPGMEXP
```

Simple V1 binder source with a single export. Key points:

- **`SIGNATURE('UTILSRV_V1')`** — named signature identifies this version. 
  Every program bound to this service program stores this signature. If the 
  interface changes a new signature prevents old programs from using an 
  incompatible version.

- **`EXPORT SYMBOL('FormatDate')`** — the procedure name exactly as it 
  appears in the source. Case matters in the binder source — `'FormatDate'` 
  and `'FORMATDATE'` are different symbols.

- **No `*PRV` levels** — this is V1 with only one export. As the service 
  program grows future versions would add `*PRV` blocks to maintain backward 
  compatibility with existing bound programs.

**What a V2 addition would look like:**

```
STRPGMEXP PGMLVL(*CURRENT) SIGNATURE('UTILSRV_V2')
  EXPORT SYMBOL('FormatDate')
  EXPORT SYMBOL('FormatPhone')     ← new procedure added
ENDPGMEXP

STRPGMEXP PGMLVL(*PRV) SIGNATURE('UTILSRV_V1')
  EXPORT SYMBOL('FormatDate')      ← original interface preserved
ENDPGMEXP
```

Programs bound to V1 still work. New programs get access to both procedures.

---

## EMPMOD — Employee Salary Update Module

Demonstrates a realistic business program that **consumes** the utility 
service program. Updates an employee's salary after displaying current 
hire date information.

### Key Legacy Patterns

**CHAIN with indicator — record not found:**
```rpgle
C     wEmpNo        CHAIN     EMPLOYEES                          50
C                   IF        *IN50 = *OFF
```
Indicator 50 is set ON when the record is NOT found. `*IN50 = *OFF` means 
the chain succeeded — record was found and locked for update.

In modern free-format:
```rpgle
chain wEmpNo EMPLOYEES;
if %found(EMPLOYEES);
```

**UPDATE with record format name:**
```rpgle
C                   UPDATE    EMPREC
```
Updates the record that was previously CHAINed — uses the record format 
name `EMPREC` not the file name `EMPLOYEES`. The CHAIN locked the record, 
UPDATE writes the changes and releases the lock.

**DSPLY for job log messages:**
```rpgle
C                   EVAL      wMessage = 'Updating salary for: '
C                                        + %TRIMR(FIRSTNAME) + ' '
C                                        + %TRIMR(LASTNAME)
C                   DSPLY                   wMessage
```
`DSPLY` writes to the job log — useful for debugging and audit trails in 
batch programs. In modern RPG `snd-msg` is preferred.

**SETON LR / RETURN:**
```rpgle
C                   SETON                                        LR
C                   RETURN
```
`*INLR = *ON` signals the runtime to clean up — close files, free storage. 
Always required at program end in OPM and cycle programs.

### File Declaration

```rpgle
FEMPLOYEES UF   E           K DISK
```

| Position | Value | Meaning |
|---|---|---|
| Name | EMPLOYEES | Physical file name |
| Type | U | Update/delete capable |
| Mode | F | Full procedural |
| E | E | Externally defined — fields from DDS |
| K | K | Keyed access |
| DISK | DISK | Database file |

---

## TESTFMT — Test Driver Program

A standalone program that exercises `FormatDate` with known input values and 
verifies output — the legacy equivalent of a unit test.

### Test Cases

```rpgle
// Known date — March 15, 2018
C                   EVAL      wTestDate = D'2018-03-15'

// US format  → expected: 03/15/2018
C                   EVAL      wResult = FormatDate(wTestDate : 'US ')

// EUR format → expected: 15.03.2018
C                   EVAL      wResult = FormatDate(wTestDate : 'EUR')

// ISO format → expected: 2018-03-15
C                   EVAL      wResult = FormatDate(wTestDate : 'ISO')

// Edge case — January 1, 2000 (leading zeros on both month and day)
C                   EVAL      wTestDate = D'2000-01-01'
C                   EVAL      wResult = FormatDate(wTestDate : 'US ')
// expected: 01/01/2000
```

The edge case on January 1, 2000 specifically tests the leading zero logic 
for both month (01) and day (01) simultaneously — a deliberate test of the 
boundary condition where both values are single digit.

**Expected output in job log:**
```
US  Format: 03/15/2018
EUR Format: 15.03.2018
ISO Format: 2018-03-15
Jan 1 2000: 01/01/2000
```

---

## Compile Order

```cl
/* 1. Compile the utility module */
CRTRPGMOD MODULE(MYLIB/UTILMOD)
          SRCFILE(MYLIB/QRPGLESRC)
          SRCMBR(UTILMOD)

/* 2. Create the service program */
CRTSRVPGM SRVPGM(MYLIB/UTILSRV)
          MODULE(MYLIB/UTILMOD)
          SRCFILE(MYLIB/QSRVSRC)
          SRCMBR(UTILSRV)
          ACTGRP(*CALLER)

/* 3. Compile employee module */
CRTRPGMOD MODULE(MYLIB/EMPMOD)
          SRCFILE(MYLIB/QRPGLESRC)
          SRCMBR(EMPMOD)

/* 4. Create employee program bound to service program */
CRTPGM PGM(MYLIB/EMPPGM)
       MODULE(MYLIB/EMPMOD)
       BNDSRVPGM(MYLIB/UTILSRV)
       ACTGRP(*NEW)

/* 5. Compile and run test driver */
CRTBNDRPG PGM(MYLIB/TESTFMT)
          SRCFILE(MYLIB/QRPGLESRC)
          SRCMBR(TESTFMT)
          BNDSRVPGM(MYLIB/UTILSRV)

CALL PGM(MYLIB/TESTFMT)
```

### When to Recompile

| Change | Action Required |
|---|---|
| Changed FormatDate logic | CRTRPGMOD UTILMOD → CRTSRVPGM UTILSRV |
| Added new procedure to UTILMOD | CRTRPGMOD UTILMOD → CRTSRVPGM UTILSRV (update binder source first) |
| Changed FormatDate parameters | Update binder source → CRTSRVPGM → recompile ALL callers |
| Changed EMPMOD logic only | CRTRPGMOD EMPMOD → CRTPGM EMPPGM |

---

## Legacy vs Modern Comparison

This example is intentionally written in legacy fixed-format style. 
The modern free-format equivalent of `FormatDate` would look like:

```rpgle
**free

ctl-opt nomain;

dcl-proc FormatDate export;
    dcl-pi *n char(10);
        pDate   date    value;
        pFormat char(3) const;
    end-pi;

    select;
        when pFormat = 'US ';
            return %char(pDate : *USA);     // MM/DD/YYYY
        when pFormat = 'EUR';
            return %char(pDate : *EUR);     // DD.MM.YYYY
        other;
            return %char(pDate : *ISO);     // YYYY-MM-DD
    endsl;

end-proc;
```

**Key differences:**

| Legacy | Modern |
|---|---|
| `H NOMAIN` | `ctl-opt nomain;` |
| `P FormatDate B / E` | `dcl-proc / end-proc` |
| `D FormatDate PI` | `dcl-pi *n` |
| Manual zero padding | `%char(date:*USA)` handles formatting |
| `SELECT/WHEN/ENDSL` | `select; when; endsl;` |
| `C RETURN wResult` | `return wResult;` |
| 30+ lines | 12 lines |

The modern version is dramatically shorter because IBM i date BIFs 
(`%char` with format codes) handle all the formatting that the legacy 
version does manually.

---

## Key Concepts for Interviews

### Q: What does NOMAIN do and when do you use it?
`NOMAIN` on the H spec tells the compiler the module has no main entry 
point — no traditional RPG program cycle. Use it on any module that 
contains only subprocedures and will be compiled into a service program. 
Without it the compiler generates unnecessary cycle code and may produce 
unexpected behavior.

### Q: What is the difference between CRTRPGMOD and CRTBNDRPG?
`CRTRPGMOD` creates a `*MODULE` object — compiled code that cannot run 
on its own. It must be bound into a `*PGM` or `*SRVPGM` before it can 
execute. `CRTBNDRPG` is a shortcut that combines `CRTRPGMOD` and `CRTPGM` 
in one step — useful for simple programs but you lose the ability to bind 
multiple modules together.

### Q: Why does CHAIN use an indicator but UPDATE doesn't?
`CHAIN` needs to communicate whether the record was found — indicator 50 
signals not-found. `UPDATE` doesn't need an indicator because it always 
updates the record that was most recently CHAINed or READ in that program — 
it's implicitly tied to the previous I/O operation. If no record is locked 
`UPDATE` causes a runtime error.

### Q: What is the EXPORT keyword on a procedure?
`EXPORT` makes the procedure visible outside the module — without it the 
procedure is private and can only be called from within the same module. 
Any procedure you want accessible from a service program must have `EXPORT`. 
The binder source then lists which exported procedures are part of the 
public interface.

---

## Development Environment

- **IBM i Version:** AS/400 / iSeries era patterns — compatible with V5R4+
- **Style:** Legacy fixed-format RPG — no free-format directives
- **Compile:** CRTRPGMOD for modules, CRTSRVPGM for service program
- **Testing:** TESTFMT standalone test driver with DSPLY output to job log

---

## Related Projects

- [Modern ILE Service Program Example](../ILE-ServiceProgram-Example) — same 
  concepts in modern free-format RPG with five version history
- [Customer Management — Foldable Subfile](../CustomerManagement) — modern 
  free-format subfile application
- [Customer Order Report](../Reports) — nested SQL cursors and control breaks
