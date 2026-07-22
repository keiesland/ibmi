# IBM i Customer Order Report
### Modern Free-Format RPG | Nested SQL Cursors | Control Break Logic | Printer File

A complete IBM i batch report program demonstrating modern free-format RPG 
development practices. Converted from legacy fixed-format RPG with native I/O 
to fully free-format ILE RPG with embedded SQL — retaining identical business 
logic while modernizing every technical pattern.

---

## Programs

| File | Type | Description |
|---|---|---|
| `FREEPORT2.SQLRPGLE` | RPG *PGM | Customer order report — main program |
| `REPORTP.PRTF` | Printer File | Report layout — headers, detail, totals |

---

## Report Overview

Produces a formatted customer order report showing all open orders and their 
detail lines for active customers — with running totals at three levels.

```
DATE: 04/20/26                    CUSTOMER ORDER REPORT              PAGE:    1

CUSTOMER:  0000001  Smith Hardware Supply            A

  ORDER#  ITEM#       DESCRIPTION           AMOUNT        STATUS
  ------  ----------  --------------------  ------------- ------

  ORD001  ITEM000001  16oz Framing Hammer          250.00  S
  ORD001  ITEM000002  Circular Saw Blade           700.00  O
  ORD001  ITEM000003  Safety Glasses 12pk          270.00  O
  ORD001  ITEM000004  Work Gloves 12pk             400.00  B

          Order Total:                           1,620.00

  ORD002  ITEM000005  Power Drill Kit              625.00  O
  ORD002  ITEM000006  Drill Bit Set                450.00  O
  ORD002  ITEM000007  Tool Belt                    280.00  S

          Order Total:                           1,355.00

          Customer Total:                        2,975.00    Orders:     2

CUSTOMER:  0000002  Jones Building Materials        A
...

          GRAND TOTAL:                          17,730.00    ORDERS:     6
```

---

## Key Features

- **Dual nested SQL cursors** — C1 fetches active customers with open orders, 
  C2 fetches detail lines for each order
- **Three-level control breaks** — order totals, customer totals, grand total
- **Filtered data** — active customers only, open orders only (`ORDSTAT = 'O'`)
- **Printer file overflow handling** — page breaks with header reprint
- **SQLSTATE error handling** — `'02000'` for not found, `<> '00000'` for errors
- **Page numbering** — increments on overflow

---

## SQL Architecture

### C1 — Customer/Order Cursor

Joins CUSTMAST and ORDERMAST to return one row per open order per active customer:

```rpgle
exec sql
    declare C1 cursor for
        select
            c.CUSNO,
            c.CUSNAME,
            c.CUSSTATUS,
            o.ORDNO,
            SUM(o.ORDAMT) as ORDTOTAL
        from KEIESLAND1.CUSTMAST  c
        join KEIESLAND1.ORDERMAST o
          on c.CUSNO    = o.CUSNO
        where c.CUSSTATUS = :pStatus
          and o.ORDSTAT   = 'O'
        group by c.CUSNO, c.CUSNAME, c.CUSSTATUS, o.ORDNO
        order by c.CUSNO, c.CUSNAME, c.CUSSTATUS, o.ORDNO;
```

### C2 — Order Detail Cursor

Fetches detail lines for the current order — reopened for each order:

```rpgle
exec sql
    declare C2 cursor for
        select
            ItemNo,
            ItemDesc,
            DetAmt,
            DetStat
        from KEIESLAND1.ORDERDET
        where OrdNo = :PORDNO
        order by ItemNo;
```

### Cursor Loop Pattern

```rpgle
// Outer loop — customers and orders
exec sql open C1;
exec sql fetch C1 into :pCusOrdDS.CusNo, ...;

dow sqlstate = '00000';

    // Control break logic here
    // ...

    // Inner loop — detail lines for current order
    if C2Open;
        exec sql close C2;
    endif;
    exec sql open C2;
    C2Open = *on;

    exec sql fetch C2 into :pOrdDetDS.ItemNo, ...;

    dow sqlstate = '00000';
        // Write detail line
        write ORDDETL;
        exec sql fetch C2 into :pOrdDetDS.ItemNo, ...;
    enddo;

    exec sql close C2;
    C2Open = *off;

    exec sql fetch C1 into :pCusOrdDS.CusNo, ...;
enddo;

exec sql close C1;
```

---

## Control Break Logic

The program tracks customer and order breaks by comparing current values 
to previous values on each C1 fetch:

```
First record      → Initialize all accumulators, write page header
Same customer     → Write order total, reset order accumulator
New customer      → Write order total + customer total, write new customer header
End of data       → Write final order total + customer total + grand total
```

**Three accumulator levels:**

| Accumulator | Resets When | Written When |
|---|---|---|
| Order total | New order | Same customer new order / new customer |
| Customer total | New customer | New customer / end of data |
| Grand total | Never | End of data only |

---

## Printer File Design

### Record Formats

| Record | Purpose | Spacing |
|---|---|---|
| `PRTHEAD` | Page header — date, title, page number | Absolute line positioning |
| `CUSHEAD` | Customer header line | SKIPB(002) |
| `ITMHEAD` | Column headings | SKIPB(002) |
| `ITMHEAD1` | Separator dashes | SPACEB(001) |
| `ORDDETL` | Detail line — one per order item | SPACEA(1) |
| `ORDTOTL` | Order total line | SKIPB(002) |
| `CUSTOTL` | Customer total line | SKIPB(002) |
| `GRDTOTL` | Grand total line | SPACEB(002) |
| `BLANKLIN` | Blank line spacer | SPACEA(001) |

### Numeric Formatting

Amount fields use `EDTWRD` rather than `EDTCDE` — required on some IBM i 
configurations for correct formatting on printer file numeric fields:

```
A            PDETAMT       13S 2     47EDTWRD('   ,   ,   ,   .  ')
```

### Overflow Handling

```rpgle
dcl-f REPORTP Printer oflind(Overflow) usropn;
dcl-s Overflow ind;

// Check overflow after each detail line
if Overflow;
    PAGENO += 1;
    write PRTHEAD;
    write ITMHEAD;
    write ITMHEAD1;
    Overflow = *off;
endif;
```

`usropn` — user open — gives explicit control over when the printer file 
opens and closes rather than automatic open at program start.

---

## Compile Order

```cl
/* 1. Printer file first */
CRTPRTF FILE(KEIESLAND1/REPORTP)
        SRCFILE(KEIESLAND1/QDDSSRC)
        SRCMBR(REPORTP)

/* 2. RPG program */
CRTSQLRPGI OBJ(KEIESLAND1/FREEPORT2)
           SRCFILE(KEIESLAND1/QRPGLESRC)
           SRCMBR(FREEPORT2)
           COMMIT(*NONE)
           CLOSQLCSR(*ENDMOD)
           DFTRDBCOL(KEIESLAND1)

/* Run it */
CALL PGM(KEIESLAND1/FREEPORT2) PARM('A')
```

The `'A'` parameter filters for Active customers. Pass `'I'` for Inactive 
or `'*'` to see all customers (requires WHERE clause adjustment).

---

## Database

### CUSTMAST — Customer Master

| Field | Type | Description |
|---|---|---|
| CUSNO | CHAR(7) | Customer number — primary key |
| CUSNAME | CHAR(30) | Customer name |
| CUSSTATUS | CHAR(1) | A=Active, I=Inactive |
| CUSBAL | PACKED(13,2) | Customer balance |

### ORDERMAST — Order Master

| Field | Type | Description |
|---|---|---|
| ORDNO | CHAR(6) | Order number — primary key |
| CUSNO | CHAR(7) | Customer number — foreign key |
| ORDSTAT | CHAR(1) | O=Open, C=Closed, X=Cancelled |
| ORDAMT | PACKED(13,2) | Order amount |

### ORDERDET — Order Detail

| Field | Type | Description |
|---|---|---|
| ORDNO | CHAR(6) | Order number — foreign key |
| DETSEQ | PACKED(3,0) | Detail sequence number |
| ITEMNO | CHAR(10) | Item number |
| ITEMDESC | CHAR(20) | Item description |
| DETAMT | PACKED(13,2) | Detail line amount |
| DETSTAT | CHAR(1) | O=Open, S=Shipped, B=Backorder |

---

## Legacy vs Modern Comparison

This program was converted from legacy fixed-format RPG. Key changes:

| Legacy Pattern | Modern Replacement |
|---|---|
| `H DFTACTGRP(*YES)` | `ctl-opt main(main) dftactgrp(*no)` |
| Fixed-format C specs | Free-format expressions |
| `EXSR` subroutines | `dcl-proc` procedures |
| `READ/READE/SETLL` native I/O | Embedded SQL cursors |
| `%EOF` / indicators | `SQLSTATE = '02000'` |
| `SETON LR` | `*inlr = *on` |
| D specs | `dcl-s` / `dcl-ds` |
| Printer file `OFLIND(*IN01)` | `oflind(Overflow)` named indicator |

---

## Lessons Learned

- **Cursor declare is static** — `DECLARE C2` must be at module level even 
  though `OPEN/FETCH/CLOSE` happen inside a loop. The precompiler processes 
  all `DECLARE` statements before any executable code.
- **C2 close before reopen** — use a flag (`C2Open ind`) to track whether C2 
  is open before closing — avoids SQL0501 on first iteration when C2 was 
  never opened.
- **Column order must match** — FETCH INTO variables must be in the exact same 
  order as the SELECT columns. Mismatch causes SQL0420 cast error when a char 
  field value goes into a packed variable.
- **Global scope for printer variables** — all printer file output variables 
  must be declared at module level. Variables declared inside a subprocedure 
  are not visible to the printer file field matching mechanism.
- **SET OPTION placement** — `exec sql set option` must be the very first SQL 
  statement in the program — before any cursor declarations.
- **naming(*sys) for library list** — use `naming(*sys)` not `naming(*sql)` 
  so unqualified table names search the library list automatically.
- **EDTWRD vs EDTCDE** — on PUB400 and some IBM i configurations `EDTCDE(1)` 
  does not work on printer file numeric fields. Use `EDTWRD` instead.
- **Printer file DDS line number rules:**
  - Records with `SPACEA` or `SPACEB` — NO line numbers on fields
  - Records with `SKIPB` or `SKIPA` — line numbers ARE allowed
  - Records with neither — line numbers REQUIRED

---

## Development Environment

- **IBM i Version:** V7R5M0
- **System:** PUB400 (free public IBM i — pub400.com)
- **Library:** KEIESLAND1
- **IDE:** VS Code with Code for IBM i extension
- **DDS Editing:** SEU (Source Entry Utility)
- **Terminal:** Mochasoft TN5250 emulator
- **Access:** IBM Access Client Solutions (ACS)

---

## Related Projects

- [Customer Management — Foldable Subfile](../CustomerManagement)
- [ILE Service Program Example](../ILE-ServiceProgram-Example)
