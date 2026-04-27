**free

Ctl-Opt main(main) DftActGrp(*No) ActGrp(*caller) Option(*Srcstmt : *NodebugIO) decedit('0.');

dcl-f REPORTP Printer oflind(Overflow) usropn;

// ====================================================
// Module Level Printer Variables
// ====================================================

// Printer File Fields
dcl-s PAGENO zoned(4:0);
dcl-s RPTDATE char(10);
dcl-s PCUSNO char(7);
dcl-s PCUSNAME char(30);
dcl-s PCUSSTATUS char(1);
dcl-s PORDNO char(6);
dcl-s PITEMNO char(10);
dcl-s PITEMDESC char(20);
dcl-s PDETAMT zoned(13:2);
dcl-s PDETSTAT char(1);

dcl-s PORDTOT zoned(13:2);
dcl-s PORDCNT zoned(7:0);
dcl-s PCUSTOT zoned(13:2);
dcl-s PCUSCNT zoned(7:0);
dcl-s PGRDTOT zoned(13:2);
dcl-s PGRDCNT zoned(7:0);
dcl-s Overflow ind;


// =============================================================
// Template data structure
//
// Customer template
// ============================================================
dcl-ds CusOrdDS qualified template;
    CusNo     char(7);
    CusName   char(30);
    CusStatus char(1);
    OrdNo     char(6);
    OrdTotal  packed(13:2);
end-ds;
// =============================================================
// Order Detail Template
// ============================================================
// Order Detail Template
dcl-ds OrdDetDS qualified template;
    ItemNo    char(10);
    ItemDesc  char(20);
    DetAmt    packed(13:2);
    DetStat   char(1);
end-ds;

// =============================================================

dcl-proc main;

    dcl-pi *n;
        pStatus char(1);
    end-pi;

    ProcessCustomer(pStatus);

    *InLR = *ON;
    return;

end-proc;

// ============================================================================
// Process Customer/Order Records to generate print output
// ============================================================================
dcl-proc ProcessCustomer;
    dcl-pi *n;
        pStatus char(1);
    end-pi;

    dcl-ds pCusOrdDS likeDS(CusOrdDS);
    dcl-ds pOrdDetDS likeDS(OrdDetDS);
    dcl-s C2Open ind inz(*off);

    RPTDATE = %char(%date():*MDY);

    exec sql
        set option commit = *none,
                   naming = *sql,
                   datfmt = *iso;


    // Gets the active customer records and all of their open orders
    exec sql
        declare c1 insensitive cursor for
            select
                  c.CusNo,
                  c.CusName,
                  c.CusStatus,
                  o.OrdNo,
                  SUM(o.ordamt) as OrdTotal
            from keiesland1.custmast c
            join keiesland1.ordermast o
              on  c.cusno = o.cusno
            where c.cusstatus = :pStatus
             and o.ordStat = 'O'
            group by c.cusno, c.cusname, c.cusstatus, o.ordno
            order by c.cusno, c.cusname, c.cusstatus, o.ordno;

    // Gets the order detail records for the matching order Number
    exec sql
        declare c2 cursor for
            select
                  ItemNo,
                  ItemDesc,
                  DetAmt,
                  DetStat
            from keiesland1.orderdet
            where OrdNo = :PORDNO
            order by ItemNo;

    exec sql open c1;
    PAGENO = 1;

    Open REPORTP;
    Write PRTHEAD;


    Dow '1';
        exec sql Fetch c1 into
            :pCusOrdDS.CusNo,
            :pCusOrdDS.CusName,
            :pCusOrdDS.CusStatus,
            :pCusOrdDS.OrdNo,
            :pCusOrdDS.OrdTotal;

        if SQLSTATE = '02000';
            leave;
        elseif SQLSTATE <> '00000';
            snd-msg 'C1 error: ' + %trim(SQLSTATE);
            leave;
        endif;


        if PCUSNO = *blanks;
            PCUSNO = pCusOrdDS.CusNo;
            PCUSNAME =  pCusOrdDS.CusName;
            PCUSSTATUS = pCusOrdDS.CusStatus;
            PORDNO =  pCusOrdDS.OrdNo;
            PORDCNT = 1;
            PCUSCNT = 1;
            PGRDCNT = 1;
            PORDTOT =  pCusOrdDS.OrdTotal;
            PCUSTOT = pCusOrdDS.OrdTotal;
            PGRDTOT = pCusOrdDS.OrdTotal;

            Write CUSHEAD;
            Write ITMHEAD;
            Write ITMHEAD1;

            // Same customer - different order number
        elseif PCUSNO =  pCusOrdDS.CusNo and PORDNO <>  pCusOrdDS.OrdNo;
            Write ORDTOTL;
            Write BLANKLIN;
            PORDNO =  pCusOrdDS.OrdNo;
            PORDCNT += 1;
            PCUSCNT += 1;
            PGRDCNT += 1;
            PORDTOT =  pCusOrdDS.OrdTotal;
            PCUSTOT +=  pCusOrdDS.OrdTotal;
            PGRDTOT +=  pCusOrdDS.OrdTotal;

            // New Customer, write previous customer's order and cust totals
        elseif PCUSNO <>  pCusOrdDS.CusNo;
            Write ORDTOTL;
            Write CUSTOTL;
            PCUSNO =  pCusOrdDS.CusNo;
            PCUSNAME = pCusOrdDS.CusName;
            PCUSSTATUS = pCusOrdDS.CusStatus;
            PORDNO =  pCusOrdDS.OrdNo;
            PORDTOT =  pCusOrdDS.OrdTotal;
            PCUSTOT = pCusOrdDS.OrdTotal;
            PORDCNT = 1;
            PCUSCNT = 1;
            PGRDCNT += 1;
            PGRDTOT += pCusOrdDS.OrdTotal;
            Write CUSHEAD;
            Write ITMHEAD;
            Write ITMHEAD1;

        endif;

        snd-msg 'Opening C2 for order: ' + %trim(PORDNO);
        exec sql close c2;

        if C2Open;
            exec sql close c2;
        endif;

        exec sql open c2;
        C2Open = *on;

        snd-msg 'C2 SQLSTATE after open: ' + SQLSTATE;

        if SQLSTATE <> '00000';
            snd-msg 'C2 open failed: ' + %trim(SQLSTATE);
            leave;
        endif;

        Dow '1';
            exec sql Fetch c2 into
            :pOrdDetDS.ItemNo,
            :pOrdDetDS.ItemDesc,
            :pOrdDetDS.DetAmt,
            :pOrdDetDS.DetStat;

            snd-msg 'C2 fetch SQLSTATE: ' + SQLSTATE;  // add this

            if SQLSTATE = '02000';
                leave;
            elseif SQLSTATE <> '00000';
                snd-msg 'C2 error: ' + %trim(SQLSTATE);
                leave;
            endif;

            PORDNO    = pCusOrdDS.OrdNo;
            PITEMNO   = pOrdDetDS.ItemNo;
            PITEMDESC = pOrdDetDS.ItemDesc;
            PDETAMT   = pOrdDetDS.DetAmt;
            PDETSTAT  = pOrdDetDS.DetStat;
            Write ORDDETL;

            If Overflow;
                PAGENO += 1;
                Write PRTHEAD;
                Overflow = *off;
            endif;

        EndDo;

        C2Open = *off;

    EndDo;

    Write ORDTOTL;
    Write BLANKLIN;
    Write CUSTOTL;
    Write GRDTOTL;
    Close REPORTP;

    exec sql close c1;

end-proc;







