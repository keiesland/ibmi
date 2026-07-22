      *---------------------------------------------------------
      * TESTFMT - Test driver for FormatDate procedure
      * Compile: CRTBNDRPG PGM(MYLIB/TESTFMT)
      *---------------------------------------------------------
      *---------------------------------------------------------
      * Prototype for FormatDate
      *---------------------------------------------------------
     D FormatDate      PR            10A
     D  pDate                          D   DATFMT(*ISO)
     D  pFormat                       3A   CONST
      *
      *---------------------------------------------------------
      * Test fields
      *---------------------------------------------------------
     D wTestDate       S               D   DATFMT(*ISO)
     D wResult         S             10A
     D wMessage        S             50A
      *
      *---------------------------------------------------------
      * Mainline
      *---------------------------------------------------------
      * Set up a known test date
     C                   EVAL      wTestDate = D'2018-03-15'
      *
      * Test US format
     C                   EVAL      wResult = FormatDate(wTestDate : 'US ')
     C                   EVAL      wMessage = 'US  Format: ' + wResult
     C                   DSPLY                   wMessage
      *
      * Test EUR format
     C                   EVAL      wResult = FormatDate(wTestDate : 'EUR')
     C                   EVAL      wMessage = 'EUR Format: ' + wResult
     C                   DSPLY                   wMessage
      *
      * Test ISO format
     C                   EVAL      wResult = FormatDate(wTestDate : 'ISO')
     C                   EVAL      wMessage = 'ISO Format: ' + wResult
     C                   DSPLY                   wMessage
      *
      * Test edge cases
     C                   EVAL      wTestDate = D'2000-01-01'
     C                   EVAL      wResult = FormatDate(wTestDate : 'US ')
     C                   EVAL      wMessage = 'Jan 1 2000: ' + wResult
     C                   DSPLY                   wMessage
      *
     C                   SETON                                        LR
     C                   RETURN
