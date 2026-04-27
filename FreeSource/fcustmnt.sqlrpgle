**free

ctl-opt main(main) dftactgrp(*no) actgrp(*new) OPTION(*SRCSTMT : *NODEBUGIO);

dcl-f CUSTMNTD Workstn IndDS(IndDS);

dcl-ds CustRecDS extname('CUSTMAST') qualified template;
end-ds;

// ============================================================
// Screen Fields
// ============================================================
dcl-ds tScreenDS qualified template;
    SCusNo     char(7);
    SCusName   char(30);
    SCusAddr1  char(30);
    SCusAddr2  char(30);
    SCusCity   char(20);
    SCusState  char(2);
    SCusZip    char(10);
    SCusPhone  char(14);
    SCusEmail  char(50);
    SCusStatus char(1);
    SCusOpenDT date;
    SCusBal    packed(13:2);
end-ds;

// ============================================================
// Indicator Data Structure
// ============================================================
dcl-ds IndDS qualified;
    F12        Ind pos(12);
    MdtChange  Ind pos(60);
    MdtDisplay Ind pos(61);
end-ds;

dcl-ds Customer likeds(CustRecDS);
dcl-ds ScreenDS likeds(tScreenDS);

// Constants
dcl-c CHGMODE '*** Change Mode ***';
dcl-c DSPMODE '*** Display Mode ***';
dcl-c MFAILURE 'Customer Not Found';
dcl-c MSUCCESS 'Customer record was updated.';
dcl-c MSTATUS  'Status must be A or I';
// dcl-c NOCHANGE 'No changes detected';

dcl-s WrkMode char(1);
dcl-s MDate zoned(8:0);
dcl-s MMsg char(79);

// Screen fields
dcl-s MCUSNAME   char(30);
dcl-s MCUSADDR1  char(30);
dcl-s MCUSADDR2  char(30);
dcl-s MCUSCITY   char(20);
dcl-s MCUSSTATE  char(2);
dcl-s MCUSZIP    char(10);
dcl-s MCUSPHONE  char(14);
dcl-s MCUSEMAIL  char(50);
dcl-s MCUSSTATUS char(1);
dcl-s MCUSBAL    packed(13:2);
dcl-s F12MSG     char(10);
dcl-s MDSPMODE   char(20);

// ============================================================
// Main
// ============================================================
dcl-proc main;
    dcl-pi *n;
        pCusNo char(7) const;
        pWrkMode char(1) const;
    end-pi;

    MDate = *Date;
    WrkMode = pWrkMode;
    MCUSNO = pCusNo;

    if WrkMode = '2';
        IndDS.MdtChange = *ON;
        IndDS.MdtDisplay = *OFF;
        F12MSG = 'F12=Cancel';
        MDSPMODE = CHGMODE;
    else;
        IndDS.MdtChange = *OFF;
        IndDS.MdtDisplay = *ON;
        F12MSG = 'F12=Return';
        MDSPMODE = DSPMODE;
    endif;

    GetCustomer(pCusNo: MMsg);
    SetScreenFields();

    ProcessMaint(pCusNo: MMsg);

    *InLR = *ON;
end-proc;

// ========================================================
// GetCustomerRecord
// loading customer data
// ============================================================
dcl-proc GetCustomer;

    dcl-pi *n;
        pCusNo char(7) const;
        pUserMsg char(50);
    end-pi;

    dcl-ds pCustomer likeDS(CustRecDS);

    pUserMsg = *blanks;
    clear pCustomer;

    exec sql
        set option commit = *none,
            naming = *sys,
            datfmt = *iso;

    monitor;

        EXEC SQL
            select
                CUSNO,
                CUSNAME,
                CUSADDR1,
                CUSADDR2,
                CUSCITY,
                CUSSTATE,
                CUSZIP,
                CUSPHONE,
                CUSEMAIL,
                CUSSTATUS,
                CUSOPENDT,
                CUSBAL
                into
                    :pCustomer.CUSNO,
                    :pCustomer.CUSNAME,
                    :pCustomer.CUSADDR1,
                    :pCustomer.CUSADDR2,
                    :pCustomer.CUSCITY,
                    :pCustomer.CUSSTATE,
                    :pCustomer.CUSZIP,
                    :pCustomer.CUSPHONE,
                    :pCustomer.CUSEMAIL,
                    :pCustomer.CUSSTATUS,
                    :pCustomer.CUSOPENDT,
                    :pCustomer.CUSBAL
                from CUSTMAST
                where CusNo = :pCusNo
                with ur;

        If SQLSTATE = '02000';
            pUserMsg = MFAILURE;
        elseIf SQLSTATE <> '00000';
            pUserMsg = 'Database error: ' + SQLSTATE;
        EndIf;

    on-error;
        pUserMsg = 'Unexpected error - GetCustomerRecord: ' + %trim(pCusNo);
        LogMessage(pUserMsg);
    endmon;

    ScreenDS = pCustomer;

end-proc;


// ============================================================
// ProcessMaint
// process maintenance screen
// ============================================================

dcl-proc ProcessMaint;
    dcl-pi *n;
        pCusNo char(7) const;
        pUserMsg char(79);
    end-pi;

    Dow *On;
        EXFMT CUSTMNT;
        MMsg = *blanks;

        select;

            when IndDS.F12;
                LEAVE;

            when WrkMode = '2';
                if CheckForChanges();

                    if ScreenDS.SCusStatus = 'A' OR
                       ScreenDS.SCusStatus = 'I';

                        UpdateCustomer(pCusNo: pUserMsg);
                        MMsg = MSUCCESS;
                    else;
                        MMsg = MSTATUS;
                    endif;

                endif;

            when WrkMode = '5';
                LEAVE;
        endsl;

    Enddo;

end-proc;

// ============================================================
// SetScreenFields
// set screen fields from ScreenDS
// ============================================================
dcl-proc SetScreenFields;
    dcl-pi *n;
    end-pi;

    MCUSNAME   = ScreenDS.SCusName;
    MCUSADDR1  = ScreenDS.SCusAddr1;
    MCUSADDR2  = ScreenDS.SCusAddr2;
    MCUSCITY   = ScreenDS.SCusCity;
    MCUSSTATE  = ScreenDS.SCusState;
    MCUSZIP    = ScreenDS.SCusZip;
    MCUSPHONE  = ScreenDS.SCusPhone;
    MCUSEMAIL  = ScreenDS.SCusEmail;
    MCUSSTATUS = ScreenDS.SCusStatus;
    MCUSBAL    = ScreenDS.SCusBal;

end-proc;

// ============================================================
// UpdateCustomer
// updates customer record using maintenance screen fields
// ============================================================
dcl-proc UpdateCustomer;
    dcl-pi *n;
        pCusNo char(7) const;
        pUserMsg char(50);
    end-pi;

    pUserMsg = *blanks;

    monitor;

        EXEC SQL
            update CUSTMAST
              set
                CUSNAME   = :MCUSNAME,
                CUSADDR1  = :MCUSADDR1,
                CUSADDR2  = :MCUSADDR2,
                CUSCITY   = :MCUSCITY,
                CUSSTATE  = :MCUSSTATE,
                CUSZIP    = :MCUSZIP,
                CUSPHONE  = :MCUSPHONE,
                CUSEMAIL  = :MCUSEMAIL,
                CUSSTATUS = :MCUSSTATUS,
                CUSBAL    = :MCUSBAL
            where CusNo   = :pCusNo;

        If sqlstate = '02000';
            pUserMsg = 'Customer not found.';
            return;
        elseIf sqlstate <> '00000';
            pUserMsg = 'Database error: ' + %char(sqlcode);
            return;
        EndIf;

    on-error;
        pUserMsg = 'Unexpected error - UpdateCustomerBalance: ' + %trim(pCusNo);
        LogMessage(pUserMsg);
        return;
    endmon;

    SetDSFields();
    MMsg = MSUCCESS;

end-proc;

// ============================================================
// SetScreenFields
// set screen fields from ScreenDS
// ============================================================
dcl-proc SetDSFields;

    dcl-pi *n;
    end-pi;

    ScreenDS.SCusName   = MCUSNAME;
    ScreenDS.SCusAddr1  = MCUSADDR1;
    ScreenDS.SCusAddr2  = MCUSADDR2;
    ScreenDS.SCusCity   = MCUSCITY;
    ScreenDS.SCusState  = MCUSSTATE;
    ScreenDS.SCusZip    = MCUSZIP;
    ScreenDS.SCusPhone  = MCUSPHONE;
    ScreenDS.SCusEmail  = MCUSEMAIL;
    ScreenDS.SCusStatus = MCUSSTATUS;
    ScreenDS.SCusBal    = MCUSBAL;

end-proc;

// ============================================================
// SetScreenFields
// set screen fields from ScreenDS
// ============================================================
dcl-proc CheckForChanges;
    dcl-pi *n Ind;
    end-pi;

    If MCUSNAME   <> ScreenDS.SCusName OR
       MCUSADDR1  <> ScreenDS.SCusAddr1 OR
       MCUSADDR2  <> ScreenDS.SCusAddr2 OR
       MCUSCITY   <> ScreenDS.SCusCity OR
       MCUSSTATE  <> ScreenDS.SCusState OR
       MCUSZIP    <> ScreenDS.SCusZip OR
       MCUSPHONE  <> ScreenDS.SCusPhone OR
       MCUSEMAIL  <> ScreenDS.SCusEmail OR
       MCUSSTATUS <> ScreenDS.SCusStatus OR
       MCUSBAL    <> ScreenDS.SCusBal;
        return *on;
    else;
        return *off;
    endif;

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



