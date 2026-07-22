**FREE

ctl-opt main(Main) dftactgrp(*no) actgrp(*new);

// Defines the Data Structure Template
dcl-ds CustDS extname('CustMast') qualified end-ds;

dcl-pr GetCustomer Ind;
    pCusNo Char(7) const;
    pCustDS LikeDs(CustDS); //
    pMsg Char(50);
end-pr;

dcl-proc Main;
    // Prompt user for customer number
    dcl-pi *n;
        pCusNo Char(7);
    end-pi;

    // ===========================================================================================
    // Instantiate data structure for customer info and message
    // C# Example
    // class Customer
    // {
    //   public string Name;
    //   public string Status;
    // }
    //  Customer cust1 = new Customer();
    //  Customer cust2 = new Customer();
    //   In RPG, we use a data structure to hold the customer info instead of a class -
    //   Called a template
    //     dcl-ds CustDS extname('CustMast') qualified end-ds;
    //   This is where we instantiate the data structure for the customer info. We will pass this to
    //   the GetCustomer procedure to fill it with data from the database.
    //     dcl-ds Customer likeds(CustDS) end-ds;
    // =============================================================================================
    dcl-ds Customer likeds(CustDS) end-ds;
    dcl-s Msg Char(50);

    if not GetCustomer(pCusNo : Customer : Msg);
        dsply %trim(Msg);
    else;
        dsply ('Customer Number: ' + %trim(pCusNo));
        dsply ('Customer Name: ' + %trim(Customer.CUSNAME));
        dsply ('Customer Status: ' + Customer.CUSSTATUS);
    EndIf;

    return;

end-proc;

dcl-proc GetCustomer;
    dcl-pi *n Ind;
        pCusNo Char(7) const;
        pCustDS LikeDs(CustDS);
        pMsg Char(50);
    end-pi;

    pMsg = *blanks; // Clear message
    clear pCustDS; // Clear output data structure

    exec sql
        select CusName,
               CusStatus
            into :pCustDS.CUSNAME,
                 :pCustDS.CUSSTATUS
            from CUSTMAST
            where CusNo = :pCusNo;

    If sqlcode = 100;
        pMsg = 'Customer not found.';
        return *Off;
    elseIf sqlcode <> 0;
        pMsg = 'Database error: ' + %char(sqlcode);
        return *Off;
    EndIf;

    return *On;

end-proc;
