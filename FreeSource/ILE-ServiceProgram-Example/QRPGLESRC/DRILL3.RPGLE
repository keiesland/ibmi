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
dcl-pr UpdateBalance;
    pCustomer  likeds(CustDS);
    pAmount    packed(11:2) const;
end-pr;

dcl-pr DisplayCustomer;
    pCustomer  likeds(CustDS) const;
end-pr;


// ============================================================
// Main
// ============================================================
dcl-proc Main;

    dcl-pi *n;
        pCusNo char(7);
    end-pi;

    dcl-ds Customer likeds(CustDS);
    dcl-s Msg char(50);

    // Get customer data
    Customer = GetCustomer(pCusNo : Msg);
    if %trim(Msg) <> *blanks;
        dsply Msg;
        return;
    endif;

    if Customer.CusStatus <> 'A';
        Msg = 'Customer is not active.';
        dsply Msg;
        return;
    endif;

    UpdateBalance(Customer : 25.00);
    DisplayCustomer(Customer);

end-proc;

// ============================================================
// UpdateBalance
// Modifies the DS passed in
// ============================================================
dcl-proc UpdateBalance;

    dcl-pi *n;
        pCustomer  likeds(CustDS);
        pAmount    packed(11:2) const;
    end-pi;

    pCustomer.CusBal += pAmount;

end-proc;

// ============================================================
// DisplayCustomer
// Read-only display of DS contents
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
