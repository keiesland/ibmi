**free

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy QSRVSRC,EXAMSRVH

dcl-f CUSTMAST disk usage(*input : *update) keyed
       extfile('KEIESLAND1/CUSTMAST')
       prefix(CM_);

// ============================================================
// CustValidate
// Validates customer exists based on customer number
// ============================================================
dcl-proc CustValidate export;
    dcl-pi *n ind;
        pCusNo  char(7) const;
        pUserMsg    char(50);
    end-pi;

    dcl-ds pCustomer likeDS(CustDS);

    pUserMsg = *blanks;

    pCustomer = GetCustomer(pCusNo: pUserMsg);
    if pUserMsg <> *blanks;
        return *off;
    endif;

    return *on;
end-proc;

// ============================================================
// CustGetName
// retrieves customer name based on customer number
// ============================================================
dcl-proc CustGetName export;
    dcl-pi *n ind;
        pCusNo    char(7) const;
        pCusName  char(30);
        pUserMsg      char(50);
    end-pi;

    dcl-ds pCustomer likeDS(CustDS);
    pUserMsg = *blanks;

    pCustomer = GetCustomer(pCusNo: pUserMsg);
    if pUserMsg <> *blanks;
        return *off;
    endif;

    pCusName = pCustomer.CusName;
    return *on;
end-proc;

// ============================================================
// GetCustomer
// loading customer data
// ============================================================
dcl-proc GetCustomer export;
    dcl-pi *n likeDS(CustDS);
        pCusNo char(7) const;
        pUserMsg char(50);
    end-pi;

    dcl-ds pCustomer likeDS(CustDS);

    pUserMsg = *blanks;
    clear pCustomer;

    monitor;

        EXEC SQL
        select CusNo,
               CusName,
               CusStatus,
               CusBal
            into :pCustomer.CusNo,
                 :pCustomer.CusName,
                 :pCustomer.CusStatus,
                 :pCustomer.CusBal
            from CUSTMAST
            where CusNo = :pCusNo;

        If sqlstate = '02000';
            pUserMsg = 'Customer not found.';
        elseIf sqlstate <> '00000';
            pUserMsg = 'Database error: ' + %char(sqlcode);
        EndIf;

    on-error;
        pUserMsg = 'Unexpected error - GetCustomer: ' + %trim(pCusNo);
        LogMessage(pUserMsg);
    endmon;

    return pCustomer;

end-proc;

// ============================================================
// UpdateCustomerBalance
// updates customer balance based on customer number and amount
// ============================================================
dcl-proc UpdateCustomerBalance export;
    dcl-pi *n ind;
        pCusNo char(7) const;
        pAmount packed(13:2) const;
        pUserMsg char(50);
    end-pi;

    pUserMsg = *blanks;

    monitor;

        EXEC SQL
            update CUSTMAST
                set CusBal = CusBal + :pAmount
               where CusNo = :pCusNo;

        If sqlstate = '02000';
            pUserMsg = 'Customer not found.';
            return *off;
        elseIf sqlstate <> '00000';
            pUserMsg = 'Database error: ' + %char(sqlcode);
            return *off;
        EndIf;

    on-error;
        pUserMsg = 'Unexpected error - UpdateCustomerBalance: ' + %trim(pCusNo);
        LogMessage(pUserMsg);
        return *off;
    endmon;

    return *on;

end-proc;

// ============================================================
// GetCustomerRecord
// loading customer data
// ============================================================
dcl-proc GetCustomerRecord export;
    dcl-pi *n likeDS(CustRecDS);
        pCusNo char(7) const;
        pUserMsg char(50);
    end-pi;

    dcl-ds pCustomerRec likeDS(CustRecDS);

    pUserMsg = *blanks;
    clear pCustomerRec;

    monitor;

        EXEC SQL
            select
                CM_CUSNO,
                CM_CUSNAME,
                CM_CUSADDR1,
                CM_CUSADDR2,
                CM_CUSCITY,
                CM_CUSSTATE,
                CM_CUSZIP,
                CM_CUSPHONE,
                CM_CUSEMAIL,
                CM_CUSSTATUS,
                CM_CUSOPENDT,
                CM_CUSBAL
                into :pCustomerRec.CUSNO,
                    :pCustomerRec.CUSNAME,
                    :pCustomerRec.CUSADDR1,
                    :pCustomerRec.CUSADDR2,
                    :pCustomerRec.CUSCITY,
                    :pCustomerRec.CUSSTATE,
                    :pCustomerRec.CUSZIP,
                    :pCustomerRec.CUSPHONE,
                    :pCustomerRec.CUSEMAIL,
                    :pCustomerRec.CUSSTATUS,
                    :pCustomerRec.CUSOPENDT,
                    :pCustomerRec.CUSBAL
                from CUSTMAST
                where CusNo = :pCusNo;

        If sqlstate = '02000';
            pUserMsg = 'Customer not found.';
        elseIf sqlstate <> '00000';
            pUserMsg = 'Database error: ' + sqlstate;
        EndIf;

    on-error;
        pUserMsg = 'Unexpected error - GetCustomerRecord: ' + %trim(pCusNo);
        LogMessage(pUserMsg);
    endmon;

    return pCustomerRec;

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
