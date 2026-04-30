             PGM

             DCL        VAR(&EMPNO) TYPE(*CHAR) LEN(6) VALUE('000010')
             DCL        VAR(&SALARY) TYPE(*DEC) LEN(9 2) +
                          VALUE(85000.00)

             CALL       PGM(*LIBL/EMPPGM) PARM((&EMPNO) (&SALARY))

             ENDPGM
