# IBM i Customer Management — Foldable Subfile Application
### Modern Free-Format RPG | ILE Architecture | Embedded SQL

A complete IBM i green screen application demonstrating modern free-format RPG 
development practices. Built from scratch on PUB400 (IBM i V7R5) as part of an 
active IBM i modernization study — converting legacy fixed-format patterns to 
fully free-format ILE RPG with embedded SQL.

---

## Programs

| File | Type | Description |
|---|---|---|
| `FCUSTINQ.RPGLE` | RPG *PGM | Foldable subfile inquiry — 2=Change, 4=Delete, 5=Display |
| `FCUSTMNT.RPGLE` | RPG *PGM | Customer maintenance — Change and Display modes |
| `FCUSTD.DSPF` | Display File | Inquiry display file — subfile, heading, message records |
| `FCUSTMNTD.DSPF` | Display File | Maintenance display file — single screen with field protection |

---

## Application Overview

### Customer Inquiry Screen (FCUSTINQ)

The inquiry screen loads all customers from DB2 using a **SQL cursor** rather than 
native file I/O — a key modernization from the legacy `READ/SETLL` pattern.

```
Customer Inquiry                              4/24/2026

 Position to customer: C000002
 2=Change    4=Delete   5=Display

 Opt Cust#     Customer Name                 Stat     Balance
     C000002   Jones Building Materials        A      8,750.50
               456 Oak Avenue    Akron         OH     44301
     C000003   Brown Construction Company      I           .00
               789 Elm Street    Columbus      OH     43001
     C000004   Wilson Plumbing Supply          A     22,100.75
               321 Pine Road     Toledo        OH     43601
                                                          More...

 F3=Exit     F5=Fold/Unfold     F12=Cancel
```

**Key features:**
- **Foldable subfile** — F5 toggles between 1-line and 2-line display per customer
- **Position to** — type a customer number to jump directly to that position in the list
- **SQL cursor loading** — subfile populated via DB2 cursor with `>=` position-to WHERE clause
- **Multiple selections** — user can type options next to multiple customers before pressing Enter
- **Individual selection clearing** — each processed selection is cleared with `UPDATE CUSTSL` 
  rather than reloading the entire subfile — preserving other pending selections
- **Single reload** — subfile reloads once after all selections are processed

**Function keys:**

| Key | Action |
|---|---|
| F3 | Exit application |
| F5 | Toggle fold/unfold |
| F12 | Cancel / return |
| Enter | Process selections |

---

### Customer Maintenance Screen (FCUSTMNT)

Called from FCUSTINQ with a customer number and mode parameter. Displays customer 
data for change or display depending on mode.

```
                    Customer Maintenance              4/24/2026

 Customer#:  C000001

 Name:        Smith Hardware Supply
 Address 1:   123 Main Street
 Address 2:
 City:        Cleveland
 State:       OH      Zip:  44101
 Phone:       (216)555-0101
 Email:       smith@hardware.com
 Status:      A    A=Active  I=Inactive
 Balance:     15,250.00

 F12=Cancel/Return
```

**Key features:**
- **Mode driven** — called with `'2'` (Change) or `'5'` (Display)
- **Field protection** — `DSPATR(PR)` conditioned by indicator 61 protects all input 
  fields in display mode — single field definition, no duplicate declarations
- **Change detection** — original values saved at load time and compared before 
  every update — database is only hit if something actually changed
- **Validation** — status must be A or I, name cannot be blank
- **Record locking** — `CHAIN` before `UPDATE` locks the record for the duration 
  of the update — preventing concurrent update conflicts
- **Monitor/On-Error** — unexpected errors caught and logged gracefully
- **No F3** — F3 exits the entire application from the inquiry screen only. 
  F12 returns one level to the subfile — consistent navigation hierarchy

**Mode behavior:**

| Mode | Fields | F12 Result |
|---|---|---|
| `'2'` Change | Input capable — user can type | Returns to subfile after save |
| `'5'` Display | Protected — read only | Returns to subfile immediately |

---

## ILE Architecture

```
FCUSTINQ (*PGM)
    │
    ├── calls FCUSTMNT (*PGM) with parms: CusNo, Mode
    │
    └── bound to FCUSTD (*FILE — WORKSTN)
              ├── CUSTSL    — Subfile record (SFL)
              ├── CUSTSC    — Subfile control record (SFLCTL)
              ├── CUSTHD    — Heading record
              └── CUSTMSG   — Message line record

FCUSTMNT (*PGM)
    └── bound to FCUSTMNTD (*FILE — WORKSTN)
              └── CUSTMNT   — Single maintenance screen record
```

**Activation groups:**
- Both programs use `actgrp(*caller)` — participating in the caller's resource 
  environment and commitment control scope
- No `*NEW` activation groups — avoids isolated transaction scope and resource leaks

---

## Key Modern RPG Patterns Demonstrated

### Fully Free Format
```rpgle
**free
ctl-opt main(main) dftactgrp(*no) actgrp(*caller)
        option(*srcstmt:*nodebugio);
```
Zero fixed columns — all declarations use `dcl-s`, `dcl-ds`, `dcl-pr`, `dcl-pi`.

### SQL Cursor with Position To
```rpgle
exec sql
    declare C1 cursor for
        select CUSNO, CUSNAME, CUSSTATUS,
               CUSBAL, CUSADDR1, CUSCITY,
               CUSSTATE, CUSZIP
        from KEIESLAND1.CUSTMAST
        where CUSNO >= :WkPosition
        order by CUSNO;
```
Single cursor handles both full load (WkPosition = *loval) and position-to navigation.

### Subfile Load Sequence
```rpgle
// 1. Clear
WsInd.WSFLCLR = *on;
WsInd.WSFLDSP = *off;
Write CUSTSC;
WsInd.WSFLCLR = *off;
WRrn = 0;

// 2. Load
exec sql open C1;
exec sql fetch C1 into :SCUSNO, :SCUSNAME ...;
dow sqlstate = '00000';
    WRrn += 1;
    Write CUSTSL;
    exec sql fetch C1 into :SCUSNO, :SCUSNAME ...;
enddo;
exec sql close C1;

// 3. Display
WsInd.WSFLDSP = *on;
Write CUSTSC;
```

### Individual Subfile Record Update
```rpgle
// Clear selection without reloading entire subfile
SFLSEL = *blanks;
update CUSTSL;
```

### Change Detection Before Database Update
```rpgle
// Compare current screen values to originals saved at load time
if MCusName  = MCusNameO  and
   MCusAddr1 = MCusAddr1O and
   MCusCity  = MCusCityO  and
   MCusState = MCusStateO and
   MCusStat  = MCusStatO;
       MMsg = 'No changes detected.';
       return;
endif;
// Only hits database if something actually changed
```

### DSPATR(PR) for Display Mode
```
A            MCUSNAME       30A  B  5 14DSPATR(UL)
A                                      LOWER
A  61                                  DSPATR(PR)
```
Single field definition — indicator 61 ON protects the field in display mode.
No need to define the same field twice with different usage codes.

### Monitor/On-Error
```rpgle
monitor;
    exec sql update CUSTMAST
        set CUSNAME   = :MCusName,
            CUSSTATUS = :MCusStat
        where CUSNO = :MCusNo;

    if sqlstate <> '00000';
        MMsg = 'Database error: ' + sqlstate;
        return;
    endif;
on-error;
    MMsg = 'Unexpected error updating customer.';
endmon;
```

---

## Display File Design Notes

### FCUSTD — Subfile Layout

The subfile record starts at **line 8** leaving lines 1-7 for headings:

```
Line 1:  Customer Inquiry title + Date
Line 2:  Position to customer# field
Line 3:  F3=Exit  F5=Fold/Unfold  F12=Cancel
Line 4:  2=Change  4=Delete  5=Display
Line 5:  (blank)
Line 6:  (blank)  
Line 7:  Opt  Cust#  Customer Name  Stat  Balance
Line 8+: Subfile records (2 lines each when folded)
Line 24: Message line
```

**SFLPAG(0007)** — 7 customers visible at once (7 records × 2 lines = 14 lines 
starting at line 8, ending at line 21, leaving lines 22-24 for footer/messages).

**Key DDS keywords:**

| Keyword | Purpose |
|---|---|
| `SFL` | Marks record as subfile |
| `SFLCTL(CUSTSL)` | Links control record to subfile |
| `SFLSIZ(0200)` | Maximum 200 subfile records |
| `SFLPAG(0007)` | 7 records visible per page |
| `SFLDSP` ind 31 | Controls whether subfile displays |
| `SFLCLR` ind 33 | Clears all subfile records on reload |
| `SFLEND(*MORE)` | Shows MORE indicator when records below |
| `OVERLAY` | Keeps heading visible during subfile display |
| `INDARA` | Separate indicator area — indicators in DS |
| `CA03/CA05/CA12` | Command Attention keys — no data sent |

### FCUSTMNTD — Field Protection Pattern

All input fields use a single `B` (input/output) definition with:
- `DSPATR(UL)` — underline shows input boundary
- `LOWER` — accepts mixed case input  
- `DSPATR(PR)` conditioned by indicator 61 — protects field in display mode

---

## Compile Order

```cl
/* 1. Display files first */
CRTDSPF FILE(KEIESLAND1/FCUSTD)
        SRCFILE(KEIESLAND1/QDDSSRC)

CRTDSPF FILE(KEIESLAND1/FCUSTMNTD)
        SRCFILE(KEIESLAND1/QDDSSRC)

/* 2. Maintenance program — called by inquiry */
CRTSQLRPGI OBJ(KEIESLAND1/FCUSTMNT)
           SRCFILE(KEIESLAND1/QRPGLESRC)
           COMMIT(*NONE)
           CLOSQLCSR(*ENDMOD)

/* 3. Inquiry program last */
CRTSQLRPGI OBJ(KEIESLAND1/FCUSTINQ)
           SRCFILE(KEIESLAND1/QRPGLESRC)
           COMMIT(*NONE)
           CLOSQLCSR(*ENDMOD)
```

**When to recompile:**

| Change | Recompile |
|---|---|
| FCUSTD changed | FCUSTD → FCUSTINQ |
| FCUSTMNTD changed | FCUSTMNTD → FCUSTMNT |
| CUSTMAST file changed | All four objects in order |
| FCUSTMNT RPG changed | FCUSTMNT only |
| FCUSTINQ RPG changed | FCUSTINQ only |

---

## Database

**CUSTMAST — Customer Master Physical File**

| Field | Type | Description |
|---|---|---|
| CUSNO | CHAR(7) | Customer number — primary key |
| CUSNAME | CHAR(30) | Customer name |
| CUSADDR1 | CHAR(30) | Address line 1 |
| CUSADDR2 | CHAR(30) | Address line 2 |
| CUSCITY | CHAR(20) | City |
| CUSSTATE | CHAR(2) | State code |
| CUSZIP | CHAR(10) | ZIP code |
| CUSPHONE | CHAR(14) | Phone number |
| CUSEMAIL | CHAR(50) | Email address |
| CUSSTATUS | CHAR(1) | A=Active, I=Inactive |
| CUSOPENDT | DATE (L) | Account open date — native IBM i date type |
| CUSBAL | PACKED(13,2) | Customer balance |

---

## Lessons Learned

These are real issues encountered and solved during development — worth knowing 
for anyone working with IBM i subfiles:

- **SFILE keyword is required** — `SFILE(CUSTSL:WRrn)` on the F spec continuation 
  line is mandatory for READC to work. Without it: `RNF5190 — not a WORKSTN subfile`
- **Subfile control overlap** — SFLPAG × lines per record + starting line must 
  not exceed line 23. Move subfile down or reduce SFLPAG if CPD7812 appears
- **EDTCDE on subfile fields** — use `EDTWRD` instead of `EDTCDE` on numeric 
  subfile fields on some IBM i configurations
- **Global scope for printer/display variables** — variables used by display file 
  field matching must be declared at module level, not inside subprocedures
- **SET OPTION placement** — in linear main programs (`ctl-opt main(main)`) 
  SET OPTION goes inside the main procedure as the first SQL statement
- **%EOF with subfiles** — `%EOF(CUSTSL)` is not valid. Use `%EOF()` with no 
  parameter after READC — checks last I/O operation
- **naming(*sys) vs naming(*sql)** — use `naming(*sys)` in SET OPTION to search 
  the library list for unqualified table names
- **CA vs CF keys** — CA (Command Attention) sends no data, CF (Command Function) 
  sends screen data. Use CA for F3/F12 exit keys, CF when you need field values

---

## Development Environment

- **IBM i Version:** V7R5M0
- **System:** PUB400 (free public IBM i — pub400.com)
- **Library:** KEIESLAND1
- **IDE:** VS Code with Code for IBM i extension
- **DDS Editing:** SEU (Source Entry Utility) — required for fixed-column DDS
- **Terminal:** Mochasoft TN5250 emulator
- **Access:** IBM Access Client Solutions (ACS)

---

## Related Projects

- [Transportation Management System — ASP.NET Core MVC](../TransportationManagementSystem.Mvc)
- [Transportation Management System — Blazor Server](../TransportationManagementSystem.Blazor)
- [IBM i Customer Order Report](../Reports)
