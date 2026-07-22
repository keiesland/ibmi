**free

ctl-opt dftactgrp(*no)
        actgrp(*new)
        option(*srcstmt:*nodebugio)
        bnddir('MYBNDDIR')
        main(Main);

// ============================================================
// Service program prototypes
// ============================================================
/copy QSRVSRC,EXAMSRVH

// ============================================================
// Report State DS
// ============================================================
dcl-ds ReportState qualified template;
    CusNo       char(7);
    CusName     char(30);
    OrderCount  packed(7:0);
    TotalAmt    packed(13:2);
end-ds;

// ============================================================
// Forward prototypes for internal procedures
// ============================================================
dcl-pr InitializeReport;
    pState likeds(ReportState);
    pCusNo char(7) const;
end-pr;

dcl-pr LoadCustomer ind;
    pState likeds(ReportState);
    pMsg   char(50);
end-pr;

dcl-pr ProcessOrders ind;
    pState likeds(ReportState);
    pMsg   char(50);
end-pr;

dcl-pr PrintSummary;
    pState likeds(ReportState) const;
end-pr;

// ============================================================
// Main Procedure
// ============================================================
dcl-proc Main;

    dcl-pi *n;
        pCusNo char(7);
    end-pi;

    dcl-ds State likeds(ReportState);
    dcl-s  pMsg   char(50);

    InitializeReport(State : pCusNo);

    if not LoadCustomer(State : pMsg);
        return;
    endif;

    if not ProcessOrders(State : pMsg);
        return;
    endif;

    snd-msg 'Success';

end-proc;

// ============================================================
// Initialize State
// ============================================================
dcl-proc InitializeReport;

    dcl-pi *n;
        pState likeds(ReportState);
        pCusNo char(7) const;
    end-pi;

    clear pState;
    pState.CusNo = pCusNo;

end-proc;

// ============================================================
// Load Customer (Service Program)
// ============================================================
dcl-proc LoadCustomer;

    dcl-pi *n ind;
        pState likeds(ReportState);
        pMsg   char(50);
    end-pi;

    if not CustValidate(pState.CusNo : pMsg);
        return *off;
    endif;

    if not CustGetName(pState.CusNo : pState.CusName : pMsg);
        return *off;
    endif;

    return *on;

end-proc;

// ============================================================
// Process Orders (SQL + Cursor)
// ============================================================
dcl-proc ProcessOrders;

    dcl-pi *n ind;
        pState likeds(ReportState);
        pMsg   char(50);
    end-pi;

    dcl-s OrderNo   packed(7:0);
    dcl-s OrderDate date;
    dcl-s OrdAmt    packed(11:2);

    exec sql
       declare OrderCur cursor for
          select OrdNo,
                 OrdDate,
                 OrdAmt
            from KEIESLAND1/ORDERHDR
           where CusNo = :pState.CusNo
           order by OrdDate;

    exec sql open OrderCur;

    if sqlcod <> 0;
        snd-msg 'Cursor open failed ' + %char(sqlcod);
        pMsg = 'Cursor open failed';
        return *off;
    endif;

    dow '1';

        exec sql
           fetch OrderCur
            into :OrderNo,
                 :OrderDate,
                 :OrdAmt;

        if sqlcod = 100;
            leave;
        endif;

        if sqlcod <> 0;
            pMsg = 'Fetch error';
            exec sql close OrderCur;
            return *off;
        endif;

        pState.OrderCount += 1;
        pState.TotalAmt   += OrdAmt;

    enddo;

    exec sql close OrderCur;

    return *on;

end-proc;

// ============================================================
// Print Summary
// ============================================================
dcl-proc PrintSummary;

    dcl-pi *n;
        pState likeds(ReportState) const;
    end-pi;

    snd-msg 'Customer: ' + %trim(pState.CusNo);
    snd-msg 'Customer Name: ' + %trim(pState.CusName);
    snd-msg 'Total Orders: ' + %char(pState.OrderCount);
    snd-msg 'Total Amount: ' + %char(pState.TotalAmt);

end-proc;


// ============================================================
//   I structure my programs with a main procedure controlling flow,
//   use subprocedures for discrete responsibilities,
//   minimize global variables by passing a data structure,
//   and use embedded SQL with cursors for efficient data processing.
//   For messaging, I wrap SNDPGMMSG to avoid DSPLY and produce proper
//   program messages.
// ============================================================E
