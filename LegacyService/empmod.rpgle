      *---------------------------------------------------------
      * EMPMOD - Employee salary update program
      * Compile: CRTRPGMOD MODULE(MYLIB/EMPMOD)
      *---------------------------------------------------------
      *
      *---------------------------------------------------------
      * File Specifications
      *---------------------------------------------------------
     FEMPLOYEES UF   E           K DISK
      *
      *---------------------------------------------------------
      * Standalone fields and constants
      *---------------------------------------------------------
     DwEmpNo           S              6A
     DwNewSalary       S              9P 2
     DwFormattedDt     S             10A
     DwMessage         S             50A
     DcPgmName         C                   CONST('EMPMOD')
      *---------------------------------------------------------
      * Prototype for FormatDate from service program
      *---------------------------------------------------------
     D FormatDate      PR            10A
     D  pDate                          D   DATFMT(*ISO)
     D  pFormat                       3A   CONST
      *---------------------------------------------------------
      * Parameter List
      *---------------------------------------------------------
     C     *ENTRY        PLIST
     C                   PARM                    wEmpNo
     C                   PARM                    wNewSalary
      *
      *---------------------------------------------------------
      * Mainline Logic
      *---------------------------------------------------------
      *
      *Chain to employee record by key
     C     wEmpNo        CHAIN     EMPLOYEES                          50
      *
     C                   IF        *IN50 = *OFF
      *
      * Format the hire date using service program procedure
     C                   EVAL      wFormattedDt =
     C                              FormatDate(HIREDATE : 'US ')
      *
      * Write to joblog before update
     C                   EVAL      wMessage = 'Hire Date: '
     C                                        + %TRIMR(wFormattedDT)
     C                   DSPLY                   wMessage
      *
     C                   EVAL      wMessage = 'Updating salary for: '
     C                                        + %TRIMR(FIRSTNAME) + ' '
     C                                        + %TRIMR(LASTNAME)
     C                   DSPLY                   wMessage
      *
      * Update the salary field
     C                   EVAL      SALARY = wNewSalary
      *
      * Update the record
     C                   UPDATE    EMPREC
      *
     C                   ELSE
      *
      * Employee not found
     C                   EVAL      wMessage = 'Employee not found: '
     C                                        + %TRIMR(wEmpNo)
     C                   DSPLY                   wMessage
      *
     C                   ENDIF
      *
      * End program
     C                   SETON                                        LR
     C                   RETURN
