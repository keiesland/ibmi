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
// Forward prototypes
// ============================================================
dcl-pr DisplayCustomer;
    pCustomer likeds(CustDS) const;
end-pr;

dcl-pr DisplayCustomerRecord;
    pCustomerRecord likeds(CustRecDS) const;
end-pr;

// ============================================================
// Main
// ============================================================
dcl-proc Main;

    dcl-pi *n;
    end-pi;


    dcl-ds Customer likeds(CustDS);
    dcl-ds CustomerRecord likeds(CustRecDS) Inz;

    dcl-s Msg char(50);
    dcl-s pCusNo char(7) inz('C000001');
    dcl-s pAmount packed(13:2) inz(500);

    // Get customer data
    Customer = GetCustomer(pCusNo : Msg);
    if %trim(Msg) <> *blanks;
        dsply %trim(Msg);
        return;
    endif;

    // Check if customer is active
    if Customer.CusStatus <> 'A';
        Msg = 'Customer is not active.';
        dsply %trim(Msg);
        return;
    endif;

    // Update customer balance
    if not UpdateCustomerBalance(pCusNo : pAmount : Msg);
        dsply %trim(Msg);
        return;
    endif;

    // Re-read business subset after update
    Customer = GetCustomer(pCusNo : Msg);
    if %trim(Msg) <> *blanks;
        dsply %trim(Msg);
        return;
    endif;

    // Display updated customer information
    DisplayCustomer(Customer);

    // Get Full Customer Record
    CustomerRecord = GetCustomerRecord(pCusNo : Msg);
    if %trim(Msg) <> *blanks;
        dsply Msg;
        return;
    endif;

    // Display full customer record
    DisplayCustomerRecord(CustomerRecord);


end-proc;

// ============================================================
// DisplayCustomer
// ============================================================
dcl-proc DisplayCustomer;

    dcl-pi *n;
        pCustomer likeds(CustDS) const;
    end-pi;

    dsply ('CusNo: ' + %trim(pCustomer.CusNo));
    dsply ('Name : ' + %trim(pCustomer.CusName));
    dsply ('Stat : ' + pCustomer.CusStatus);
    dsply ('Bal  : ' + %char(pCustomer.CusBal));

end-proc;

// ============================================================
// DisplayCustomerRecord
// ============================================================
dcl-proc DisplayCustomerRecord;

    dcl-pi *n;
        pCustomerRecord likeds(CustRecDS) const;
    end-pi;

    dsply ('CusNo: ' + %trim(pCustomerRecord.CUSNO));
    dsply ('Name : ' + %trim(pCustomerRecord.CUSNAME));
    dsply ('Add1 : ' + %trim(pCustomerRecord.CUSADDR1));
    dsply ('Add2 : ' + %trim(pCustomerRecord.CUSADDR2));
    dsply ('City : ' + %trim(pCustomerRecord.CUSCITY));
    dsply ('State: ' + %trim(pCustomerRecord.CUSSTATE));
    dsply ('Zip  : ' + %trim(pCustomerRecord.CUSZIP));
    dsply ('Phone : ' + %trim(pCustomerRecord.CUSPHONE));
    dsply ('Stat : ' + pCustomerRecord.CUSSTATUS);
    dsply ('Bal  : ' + %char(pCustomerRecord.CUSBAL));


end-proc;
