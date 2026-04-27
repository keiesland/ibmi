**free

ctl-opt main(main) dftactgrp(*no) actgrp(*new) OPTION(*SRCSTMT : *NODEBUGIO);

dcl-f CUSTD2 Workstn IndDS(WsInd) sfile(CUSTSL:WRrn);

// ============================================================
// Indicator Data Structure
// ============================================================
dcl-ds WsInd qualified;
    WF03       Ind pos(03);
    WF05       Ind pos(05);
    WSFLDSP    Ind pos(31);
    WSFLEMP    Ind pos(32);
    WSFLCLR    Ind pos(33);
end-ds;

dcl-pr FCUSTMNT extpgm('FCUSTMNT');
    pCusNo char(7);
    pMode char(1);
end-pr;

dcl-s pCusNo char(7);
dcl-s pMode char(1);
dcl-s WkPosition char(7) inz(*loval);

// ============================================================
// Subfile Fields
// ============================================================
dcl-s SCUSADDR1  char(30);
dcl-s SCUSADDR2  char(30);
dcl-s SCUSBAL    packed(13:2);
dcl-s SCUSCITY   char(20);
dcl-s SCUSNAME   char(30);
dcl-s SCUSNO     char(7);
dcl-s SCUSPHONE  char(14);
dcl-s SCUSSTATE  char(2);
dcl-s SCUSSTATUS char(1);
dcl-s SCUSZIP    char(10);
dcl-s SFLSEL     char(1);

// ============================================================
// Screen Fields
// ============================================================
dcl-s HDATE      zoned(8:0);
dcl-s HPOSIT     char(7);
dcl-s WConfirm   char(1);
dcl-s WCusNo     char(7);
dcl-s WFold      char(1);
dcl-s WFoldFlag  char(1) inz('0');
dcl-s WMode      char(1);
dcl-s WMSG       char(79);
dcl-s WRrn       packed(4:0);

// ==================================================
// MAIN Procedure
// ==================================================
dcl-proc main;
    dcl-pi *n;
    end-pi;

    HDATE = *DATE;
    WMSG = *Blanks;

    LoadSubfile();
    ProcessSubfile();

    *InLR = *ON;
    return;

end-proc;

// ==================================================
// LoadSubfile Procedure
// ==================================================
dcl-proc LoadSubfile;
    dcl-pi *n;
    end-pi;

    // Reset subfile
    WsInd.WSFLCLR = *ON;
    WsInd.WSFLDSP = *OFF;
    Write CUSTSC;
    WsInd.WSFLCLR = *OFF;
    WRrn = 0;

    if HPOSIT <> *Blanks;
        WkPosition = HPOSIT;
    else;
        WkPosition = *loval;
    endif;

    exec sql
        set option commit = *none,
                   naming = *sys,
                   datfmt = *iso;

    // Gets the active customer records and all of their open orders
    exec sql
        declare c1 cursor for
            select
                  CUSNO,
                  CUSNAME,
                  CUSADDR1,
                  CUSADDR2,
                  CUSBAL,
                  CUSCITY,
                  CUSPHONE,
                  CUSSTATE,
                  CUSSTATUS,
                  CUSZIP
            from KEIESLAND1.CUSTMAST
            where CUSNO >= :WkPosition
            order by CUSNO;

    exec sql close c1;
    exec sql open c1;

    Dow '1';
        exec sql Fetch c1 into
                 :SCUSNO,
                 :SCUSNAME,
                 :SCUSADDR1,
                 :SCUSADDR2,
                 :SCUSBAL,
                 :SCUSCITY,
                 :SCUSPHONE,
                 :SCUSSTATE,
                 :SCUSSTATUS,
                 :SCUSZIP;

        if SQLSTATE = '02000';
            leave;
        elseif SQLSTATE <> '00000';
            snd-msg 'C1 error: ' + %trim(SQLSTATE);
            leave;
        endif;

        WRrn += 1;
        Write CUSTSL;

    Enddo;

    if WRrn > 0;
        WsInd.WSFLDSP = *ON;
        WsInd.WSFLEMP = *OFF;
    else;
        WsInd.WSFLDSP = *OFF;
        WsInd.WSFLEMP = *ON;
    endif;

    Write CUSTSC;

    exec sql close c1;

end-proc;


// ==================================================
// PROCESS SUBFILE LOOP
// ==================================================
dcl-proc ProcessSubfile;
    dcl-pi *n;
    end-pi;

    Dow *on;

        Write CUSTFTR;
        EXFMT CUSTSC;

        select;
            when WsInd.WF03;
                leave;

            when WsInd.WF05;
                FoldRoutine();
                iter;

            when HPOSIT <> *Blanks;
                LoadSubfile();
                WMSG = *Blanks;
                iter;

        endsl;

        ProcessSelection();
        WMSG = *Blanks;

    Enddo;

end-proc;

// ==================================================
// FOLD / UNFOLD ROUTINE
// ==================================================
dcl-proc FoldRoutine;
    dcl-pi *n;
    end-pi;

    if WFoldFlag = '0';
        WFold = 'Y';
        WMSG = 'Subfile folded.';
    else;
        WFold = 'N';
        WMSG = 'Subfile unfolded.';
    endif;

    LoadSubfile();

end-proc;

// ===================================================
// Process Selection
// ===================================================
dcl-proc ProcessSelection;
    dcl-pi *n;
    end-pi;

    WRrn = 0;

    Readc CUSTSL;
    dow not %eof();

        select;
            when SFLSEL = '2';
                WCusNo = SCUSNO;
                WMode = '2';

                pCusNo = SCUSNO;
                pMode = WMode;
                FCUSTMNT(pCusNo : pMode);
                SFLSEL = *Blanks;
                Update CUSTSL;

            when SFLSEL = '4';
                DeleteCustomer();
                SFLSEL = *Blanks;
                Update CUSTSL;

            when SFLSEL  = '5';
                WCusNo = SCUSNO;
                WMode = '5';
                pCusNo = SCUSNO;
                pMode = WMode;
                FCUSTMNT(pCusNo : pMode);
                SFLSEL = *Blanks;
                Update CUSTSL;

            other;
                WMSG = SCUSNO + ': Invalid selection -' + SFLSEL;
                Write CUSTFTR;
                SFLSEL = *Blanks;
                Update CUSTSL;

        endsl;

        Readc CUSTSL;
    enddo;

    LoadSubfile();

end-proc;

// ============================================================
// DeleteCustomer
// deletes customer record matching key SCUSNO
// ============================================================
dcl-proc DeleteCustomer;
    dcl-pi *n;
    end-pi;

    WMSG = 'Delete customer ' + %Trim(SCUSNO) + ' - ' +
            %trim(SCUSNAME) + '? Enter Y to confirm:';
    Write CUSTFTR;
    Exfmt CUSTSC;

    IF WsInd.WF03;
        WMSG = 'Delete cancelled.';
        HPOSIT = *Blanks;
        return;
    endif;

    WConfirm = HPOSIT;
    HPOSIT = *Blanks;

    if WConfirm = 'Y';

        monitor;
            exec sql
                  delete CUSTMAST
                  where CusNo   = :SCUSNO;

            If sqlstate = '02000';
                WMSG = 'Customer ' + %trim(SCUSNO) + ' not found.';
                return;
            elseIf sqlstate <> '00000';
                WMSG = 'Database error: ' + %char(sqlcode);
                return;
            EndIf;

        on-error;
            WMSG = 'Unexpected error deleting customer: ' + %trim(SCUSNO);
            LogMessage(WMSG);
            return;
        endmon;

    endif;

    WMSG = 'Customer ' + %trim(SCUSNO) + ' deleted successfully.';

end-proc;

// ============================================================
// logMessage
// ============================================================
dcl-proc LogMessage;
    dcl-pi *n;
        pUserMsg char(50) const;
    end-pi;

    dsply %trim(pUserMsg);

end-proc;

