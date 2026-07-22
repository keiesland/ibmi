**free

// ============================================================
// Customer template
// ============================================================
dcl-ds CustDS qualified template;
    CusNo     char(7);
    CusName   char(30);
    CusStatus char(1);
    CusBal    packed(13:2);
end-ds;

// Full customer record template
dcl-ds CustRecDS extname('CUSTMAST') qualified template;
end-ds;

// ============================================================
// Exported procedure prototypes
// ============================================================
dcl-pr CustGetName ind extproc('CustGetName');
    pCusNo     char(7) const;
    pCusName   char(30);
    pMsg       char(50);
end-pr;

Dcl-Pr CustValidate Ind ExtProc('CustValidate');
    pCusNo  Char(7)  Const;
    pMsg    Char(50);
End-Pr;

dcl-pr GetCustomer likeDS(CustDS) extproc('GetCustomer');
    pCusNo char(7) const;
    pMsg char(50);
end-pr;

dcl-pr UpdateCustomerBalance Ind extproc('UpdateCustomerBalance');
    pCusNo char(7) const;
    pAmount packed(13:2) const;
    pMsg char(50);
end-pr;

dcl-pr GetCustomerRecord likeDS(CustRecDS) extproc('GetCustomerRecord');
    pCusNo char(7) const;
    pMsg char(50);
end-pr;
