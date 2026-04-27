**free

ctl-opt dftactgrp(*no)
        actgrp(*caller)
        option(*srcstmt:*nodebugio)
        main(Main);


// ============================================================
// Customer template
// ============================================================
dcl-ds CustDS qualified template;
    CusNo     char(7);
    CusName   char(30);
    CusBal    packed(13:2);
end-ds;

// ============================================================
// Forward prototypes
// ============================================================
dcl-pr GetCustomer Ind;
    pCusNo Char(7) const;
    pCustDS LikeDs(CustDS); //
    pMsg Char(50);
end-pr;

// ============================================================
// Main
// ============================================================
dcl-proc Main;

    dcl-pi *n;
        pCusNo char(7) const;
    end-pi;

    dcl-ds Customer likeds(CustDS);
    dcl-s UserMsg char(50);

    // Get customer data
    if not GetCustomer(pCusNo : Customer : UserMsg);
        dsply %trim(UserMsg);
    else;
        dsply ('Customer Number: ' + %trim(pCusNo));
        dsply ('Customer Name: ' + %trim(Customer.CusName));
        dsply ('Customer Balance : ' + %char(Customer.CusBal));
    EndIf;

end-proc;

// ============================================================
// Get customer data
// ============================================================
dcl-proc GetCustomer;
    dcl-pi *n Ind;
        pCusNo Char(7) const;
        pCustDS LikeDs(CustDS);
        pMsg Char(50);
    end-pi;

    dcl-ds NullInds qualified;
        CusNam int(5);
        CusBal int(5);
    end-ds;

    pMsg = *blanks; // Clear message
    clear pCustDS; // Clear output data structure

    exec sql
        select CusName,
               CusBalance
            into :pCustDS.CusName :NullInds.CusNam,
                 :pCustDS.CusBal :NullInds.CusBal
            from CUSTMAST
            where CusNo = :pCusNo;

    If sqlstate = '02000';
        pMsg = 'Customer not found.';
        return *Off;
    elseIf sqlstate <> '00000';
        pMsg = 'Database error SQLSTATE ' + %trimr(sqlstate);
        return *Off;
    EndIf;

    return *On;

end-proc;
