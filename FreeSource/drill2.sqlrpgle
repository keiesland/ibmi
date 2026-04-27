**free
ctl-opt main(Main) dftactgrp(*no) actgrp(*new);

// ============================================================
// Customer template
// ============================================================
dcl-ds CustDS extname('CUSTMAST') qualified template;
end-ds;

// ============================================================
// Forward prototypes
// ============================================================
dcl-pr GetCustomer ind;
    pCusNo     char(7) const;
    pCustomer  likeds(CustDS);
    pMsg       char(50);
end-pr;

dcl-pr UpdateBalance;
    pCustomer  likeds(CustDS);
    pAmount    packed(11:2) const;
end-pr;

dcl-pr DisplayCustomer;
    pCustomer  likeds(CustDS) const;
end-pr;

dcl-pr CheckActive ind;
    pCustomer  likeds(CustDS) const;
    pMsg       char(50);
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

    clear Customer;

    if not GetCustomer(pCusNo : Customer : Msg);
        dsply %trim(Msg);
        return;
    endif;

    if not CheckActive(Customer : Msg);
        dsply %trim(Msg);
        return;
    endif;

    UpdateBalance(Customer : 25.00);
    DisplayCustomer(Customer);

end-proc;

// ============================================================
// GetCustomer
// Simulates loading customer data
// ============================================================
dcl-proc GetCustomer;

    dcl-pi *n ind;
        pCusNo     char(7) const;
        pCustomer  likeds(CustDS);
        pMsg       char(50);
    end-pi;

    pMsg = *blanks;
    clear pCustomer;


    exec sql
        select CusNo,
               CusName,
               CusStatus,
               CusBal
            into :pCustomer.CUSNO,
                 :pCustomer.CUSNAME,
                 :pCustomer.CUSSTATUS,
                 :pCustomer.CUSBAL
            from CUSTMAST
            where CusNo = :pCusNo;

    If sqlstate = '02000';
        pMsg = 'Customer not found.';
        return *Off;
    elseIf sqlstate <> '00000';
        pMsg = 'Database error: ' + sqlstate;
        return *Off;
    EndIf;

    return *On;

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

    pCustomer.CUSBAL += pAmount;

end-proc;

// ============================================================
// DisplayCustomer
// Read-only display of DS contents
// ============================================================
dcl-proc DisplayCustomer;

    dcl-pi *n;
        pCustomer likeds(CustDS) const;
    end-pi;

    dsply ('CusNo: ' + %trim(pCustomer.CUSNO));
    dsply ('Name : ' + %trim(pCustomer.CUSNAME));
    dsply ('Stat : ' + pCustomer.CUSSTATUS);
    dsply ('Bal  : ' + %char(pCustomer.CUSBAL));

end-proc;

// ============================================================
// CheckActive
// Read-only display of DS contents
// ============================================================
dcl-proc CheckActive;

    dcl-pi *n ind;
        pCustomer likeds(CustDS) const;
        pMsg       char(50);
    end-pi;

    if pCustomer.CUSSTATUS <> 'A';
        pMsg = 'Customer inactive';
        return *off;
    endif;

    return *on;
end-proc;



