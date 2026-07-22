# ILE Service Program Example
### IBM i ILE Architecture | Service Programs | Binder Source | Version Management

A complete IBM i ILE service program example demonstrating real-world service 
program design — including five generations of version evolution showing how 
production service programs grow over time while maintaining full backward 
compatibility with existing bound programs.

---

## Files

| File | Type | Description |
|---|---|---|
| `EXAMSRV.SQLRPGLE` | RPG Module | Service program procedures — exported business logic |
| `EXAMPGM.SQLRPGLE` | RPG *PGM | Example calling program — demonstrates usage |
| `EXAMSRVB.BND` | Binder Source | Export definitions and version signatures |
| `EXAMSRVH.RPGLE` | Copy Book | Prototype declarations — `/copy` into calling programs |

---

## What This Demonstrates

This example covers the complete ILE service program pattern that every IBM i 
developer should know:

```
EXAMSRVH.RPGLE     ← prototype copy book
    ↓ /copy
EXAMPGM.SQLRPGLE   ← calling program references prototypes
    ↓ calls at runtime
EXAMSRV.SQLRPGLE   ← service program module (exported procedures)
    ↓ exports defined by
EXAMSRVB.BND       ← binder source (the contract)
    ↓ compiled into
*SRVPGM object     ← reusable library bound to calling programs
```

---

## Exported Procedures — Current Version (V5R0)

| Procedure | Description |
|---|---|
| `GetCustomer` | Fetches a customer record by customer number using embedded SQL |
| `CustGetName` | Returns customer name for a given customer number |
| `CustValidate` | Validates customer number exists and is active |
| `UpdateCustomerBalance` | Updates customer balance — validates before writing |
| `GetCustomerRecord` | Returns full customer data structure to caller |

---

## Version Evolution — The Real World Story

One of the most valuable things this example demonstrates is **how service 
programs grow over time in production** while maintaining backward compatibility.

### EXAMSRVB.BND — Binder Source

```
STRPGMEXP  PGMLVL(*CURRENT)  SIGNATURE('EXAMSRV V5R0')
  EXPORT SYMBOL('GetCustomer')
  EXPORT SYMBOL('CustGetName')
  EXPORT SYMBOL('CustValidate')
  EXPORT SYMBOL('UpdateCustomerBalance')
  EXPORT SYMBOL('GetCustomerRecord')          ← added in V5R0
ENDPGMEXP

STRPGMEXP  PGMLVL(*PRV)  SIGNATURE('EXAMSRV V4R0')
  EXPORT SYMBOL('GetCustomer')
  EXPORT SYMBOL('CustGetName')
  EXPORT SYMBOL('CustValidate')
  EXPORT SYMBOL('UpdateCustomerBalance')      ← added in V4R0
ENDPGMEXP

STRPGMEXP  PGMLVL(*PRV)  SIGNATURE('EXAMSRV V3R0')
  EXPORT SYMBOL('GetCustomer')
  EXPORT SYMBOL('CustGetName')
  EXPORT SYMBOL('CustValidate')
ENDPGMEXP

STRPGMEXP  PGMLVL(*PRV)  SIGNATURE('EXAMSRV V2R0')
  EXPORT SYMBOL('GetCustomer')
  EXPORT SYMBOL('CheckActive')               ← existed in V2, removed in V3
  EXPORT SYMBOL('CustGetName')
  EXPORT SYMBOL('CustValidate')
ENDPGMEXP

STRPGMEXP  PGMLVL(*PRV)  SIGNATURE('EXAMSRV V1R0')
  EXPORT SYMBOL('CustValidate')             ← started with just 2 procedures
  EXPORT SYMBOL('CustGetName')
ENDPGMEXP
```

### What the Version History Tells Us

```
V1R0  Started simple — validation and name lookup only
  + CustValidate
  + CustGetName

V2R0  Added customer retrieval and active check
  + GetCustomer
  + CheckActive

V3R0  Consolidated — CheckActive absorbed into CustValidate
  - CheckActive  (removed — functionality merged elsewhere)

V4R0  Added balance update capability
  + UpdateCustomerBalance

V5R0  Added full record retrieval
  + GetCustomerRecord
```

This is exactly how real production service programs evolve — new procedures 
added in `*CURRENT`, old interfaces preserved in `*PRV` blocks so existing 
bound programs never need recompilation.

---

## ILE Architecture — Key Concepts

### Why Service Programs?

Instead of duplicating customer validation logic in every program:

```rpgle
// Without service program — copy/paste in every program
if CusNo = *blanks or CusStatus <> 'A';
    ErrMsg = 'Invalid customer';
    return *off;
endif;
```

With a service program — one place, used everywhere:

```rpgle
// With service program — clean, reusable, consistent
if not CustValidate(CusNo : ErrMsg);
    return *off;
endif;
```

One fix in the service program updates every program that uses it — 
automatically, without recompiling the calling programs.

### Binding Directory

Service programs are typically collected into a binding directory so calling 
programs don't need to reference each service program individually:

```cl
CRTBNDDIR BNDDIR(KEIESLAND1/KEIBNDDIR)
ADDBNDDIRE BNDDIR(KEIESLAND1/KEIBNDDIR) OBJ((KEIESLAND1/EXAMSRV *SRVPGM))
```

Then in any calling program:
```rpgle
ctl-opt bnddir('KEIESLAND1/KEIBNDDIR');
```

Like a NuGet package reference in .NET — one reference gives access to 
everything in the binding directory.

### Activation Groups

```rpgle
// Service program — always *CALLER
ctl-opt actgrp(*caller);
```

`*CALLER` ensures the service program runs in the same activation group as 
the calling program — critical for:

- **Commitment control** — `COMMIT`/`ROLLBACK` in the caller includes service 
  program database changes. With `*NEW` the service program's changes are in 
  a separate transaction scope and won't roll back with the caller.
- **Resource sharing** — open files, cursors, and storage are shared
- **No orphaned resources** — cleaned up when caller ends

### Signatures — Backward Compatibility

IBM i generates a **signature** for each service program based on its exported 
interface. Every bound program stores the signature it was compiled against.

```
Program compiled against V3R0 signature → stores V3R0 signature
Service program updated to V5R0         → V3R0 signature preserved in *PRV
Program still runs                      → matches V3R0 signature in *PRV
```

**The golden rule — never remove or reorder exports in a *PRV block.**
Only add new procedures to `*CURRENT`. Removing or reordering breaks the 
signature match for existing programs even with a `*PRV` block present.

---

## Prototype Header — EXAMSRVH.RPGLE

The prototype header is a copy book that defines the procedure interfaces. 
Any program calling the service program includes it with `/copy`:

```rpgle
/copy KEIESLAND1/QRPGLESRC,EXAMSRVH
```

This tells the compiler exactly what parameters each procedure expects — 
enabling parameter type checking at compile time rather than runtime failures.

```rpgle
// Example prototypes from EXAMSRVH.RPGLE

dcl-pr CustValidate ind;
    pCusNo   char(7)  const;
    pUserMsg char(50);
end-pr;

dcl-pr CustGetName char(30);
    pCusNo char(7) const;
end-pr;

dcl-pr GetCustomerRecord ind;
    pCusNo    char(7)        const;
    pCustomer likeds(CustDS);
    pUserMsg  char(50);
end-pr;

dcl-pr UpdateCustomerBalance ind;
    pCusNo      char(7)     const;
    pNewBalance packed(13:2) const;
    pUserMsg    char(50);
end-pr;
```

---

## Service Program Procedures

### CustValidate
Validates that a customer number exists in the database and is active:
```rpgle
dcl-proc CustValidate export;
    dcl-pi *n ind;
        pCusNo   char(7)  const;
        pUserMsg char(50);
    end-pi;

    if pCusNo = *blanks;
        pUserMsg = 'Customer number is required.';
        return *off;
    endif;

    exec sql
        select count(*)
        into :WkCount
        from CUSTMAST
        where CUSNO     = :pCusNo
          and CUSSTATUS = 'A';

    if WkCount = 0;
        pUserMsg = 'Customer not found or inactive.';
        return *off;
    endif;

    return *on;
end-proc;
```

### GetCustomerRecord
Returns a full customer data structure to the caller — null indicators 
handle nullable columns:
```rpgle
dcl-proc GetCustomerRecord export;
    dcl-pi *n ind;
        pCusNo    char(7)        const;
        pCustomer likeds(CustDS);
        pUserMsg  char(50);
    end-pi;

    clear pCustomer;
    pUserMsg = *blanks;

    exec sql
        select CUSNO, CUSNAME, CUSADDR1, CUSADDR2,
               CUSCITY, CUSSTATE, CUSZIP,
               CUSPHONE, CUSEMAIL, CUSSTATUS, CUSBAL
        into :pCustomer.CUSNO,   :NullInds.CUSNO,
             :pCustomer.CUSNAME, :NullInds.CUSNAME,
             // ... remaining fields
        from CUSTMAST
        where CUSNO = :pCusNo
        with ur;

    if sqlstate = '02000';
        pUserMsg = 'Customer ' + %trim(pCusNo) + ' not found.';
        return *off;
    elseif sqlstate <> '00000';
        pUserMsg = 'Database error: ' + sqlstate;
        return *off;
    endif;

    return *on;
end-proc;
```

---

## Example Calling Program — EXAMPGM

Shows how a program uses the service program via the prototype header:

```rpgle
**free

ctl-opt main(main) dftactgrp(*no) actgrp(*caller)
        bnddir('KEIESLAND1/KEIBNDDIR')
        option(*srcstmt:*nodebugio);

/copy KEIESLAND1/QRPGLESRC,EXAMSRVH    // ← prototype header

dcl-ds CustDS extname('CUSTMAST') qualified end-ds;
dcl-s  UserMsg char(50);
dcl-s  CusNo   char(7);

dcl-proc main;
    dcl-pi *n;
        pCusNo char(7) const;
    end-pi;

    CusNo = pCusNo;

    // Validate first
    if not CustValidate(CusNo : UserMsg);
        snd-msg %trim(UserMsg);
        return;
    endif;

    // Get full record
    if not GetCustomerRecord(CusNo : CustDS : UserMsg);
        snd-msg %trim(UserMsg);
        return;
    endif;

    // Use the data
    snd-msg 'Customer: ' + %trim(CustDS.CUSNAME);
    snd-msg 'Balance:  ' + %char(CustDS.CUSBAL);

    *inlr = *on;
end-proc;
```

---

## Compile Order

```cl
/* 1. Compile the module */
CRTRPGMOD MODULE(KEIESLAND1/EXAMSRV)
          SRCFILE(KEIESLAND1/QRPGLESRC)
          SRCMBR(EXAMSRV)

/* 2. Create the service program */
CRTSRVPGM SRVPGM(KEIESLAND1/EXAMSRV)
          MODULE(KEIESLAND1/EXAMSRV)
          SRCFILE(KEIESLAND1/QSRVSRC)
          SRCMBR(EXAMSRVB)
          ACTGRP(*CALLER)

/* 3. Add to binding directory */
CRTBNDDIR BNDDIR(KEIESLAND1/KEIBNDDIR)
ADDBNDDIRE BNDDIR(KEIESLAND1/KEIBNDDIR)
          OBJ((KEIESLAND1/EXAMSRV *SRVPGM))

/* 4. Compile example calling program */
CRTSQLRPGI OBJ(KEIESLAND1/EXAMPGM)
           SRCFILE(KEIESLAND1/QRPGLESRC)
           SRCMBR(EXAMPGM)
           COMMIT(*NONE)
           CLOSQLCSR(*ENDMOD)

/* Run it */
CALL PGM(KEIESLAND1/EXAMPGM) PARM('0000001')
```

### When to Recompile

| Change | Recompile |
|---|---|
| Added new procedure to EXAMSRV | EXAMSRV module → EXAMSRV srvpgm |
| Changed existing procedure logic | EXAMSRV module → EXAMSRV srvpgm |
| Added new export to binder source | EXAMSRV srvpgm only |
| Added procedure to prototype header | EXAMPGM (and any other callers) |
| Existing bound programs after srvpgm recompile | NOT required if *PRV maintained |

---

## Key Interview Concepts

### Q: What is a service program and why use one?
A service program (`*SRVPGM`) is a reusable library of exported procedures 
with no main entry point. It's IBM i's equivalent of a .NET class library 
(.dll). Use it when the same business logic is needed across multiple programs — 
one fix updates all callers automatically without recompiling them.

### Q: What is the binder source and why is it important?
The binder source defines the service program's public interface — which 
procedures are exported and in what order. IBM i uses this to generate a 
signature that bound programs store. The `*PRV` levels maintain old signatures 
so existing programs don't break when new procedures are added.

### Q: Why must service programs use *CALLER activation group?
With `*NEW` the service program runs in a separate activation group from the 
caller. This breaks commitment control — a `ROLLBACK` in the calling program 
won't include the service program's database changes. `*CALLER` puts both in 
the same activation group so all database changes participate in the same 
transaction scope.

### Q: What happens if you remove an export from a *PRV block?
Existing programs bound to that signature will fail at runtime with a 
signature mismatch error. You can only ADD procedures to `*CURRENT` — never 
remove or reorder exports in any `*PRV` block.

### Q: What is the prototype header and why separate it?
The prototype header (`EXAMSRVH`) is a copy book containing the procedure 
interface declarations. Separating it means any program that needs to call 
the service program just does `/copy EXAMSRVH` rather than redeclaring all 
the prototypes. Change a parameter once in the header and all callers 
recompile cleanly.

---

## C# / .NET Equivalents

For developers coming from a .NET background:

| IBM i ILE Concept | .NET Equivalent |
|---|---|
| `*MODULE` | Compiled class (not yet executable) |
| `*SRVPGM` | Class library (.dll) |
| `*PGM` | Executable (.exe) |
| Binding Directory | NuGet package / project reference |
| `export` keyword | `public` method |
| Prototype (`dcl-pr`) | Method signature / interface |
| Copy book (`/copy`) | `using` statement + interface definition |
| Binder source | Assembly manifest / interface contract |
| `*PRV` signatures | Assembly versioning / backward compatibility |
| `actgrp(*caller)` | Shared AppDomain / transaction scope |

---

## Development Environment

- **IBM i Version:** V7R5M0
- **System:** PUB400 (free public IBM i — pub400.com)
- **Library:** KEIESLAND1
- **IDE:** VS Code with Code for IBM i extension
- **Terminal:** Mochasoft TN5250 emulator
- **Access:** IBM Access Client Solutions (ACS)

---

## Related Projects

- [Customer Management — Foldable Subfile](../CustomerManagement)
- [Customer Order Report](../Reports)
- [Transportation Management — ASP.NET Core MVC](../../TransportationManagementSystem.Mvc)
