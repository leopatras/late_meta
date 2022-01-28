DEFINE _host INT
&define MYASSERT(x) IF NOT NVL(x,0) THEN CALL myErr("ASSERTION failed in line:"||__LINE__||":"||#x) END IF
MAIN
  IF fgl_getenv("META_HOST") IS NOT NULL THEN
    CALL send_meta()
    RETURN
  END IF
  MENU
    COMMAND "start"
      CALL sub()
    --COMMAND "RUN ww"
    --  RUN "fglrun main" WITHOUT WAITING
    COMMAND "env"
      RUN "env | grep FGLFEID"
    COMMAND "exit"
      EXIT MENU
  END MENU
END MAIN

FUNCTION sub()
  DEFINE vmmeta, climeta, ppid, host, myProcId, om STRING
  CONSTANT mypid = 7777777
  DEFINE port INT
  LET ppid = qa_getAttr(0, "procId")
  LET host = getHost(ppid)
  CALL fgl_setenv("META_HOST", host)
  CALL fgl_setenv("META_PPID", ppid)
  RUN "fglrun meta" WITHOUT WAITING
END FUNCTION

FUNCTION send_meta()
  DEFINE vmmeta, climeta, ppid, host, myProcId, om, resp,name  STRING
  DEFINE port, omNum INT
  DEFINE s1 base.Channel
  LET s1 = base.Channel.create()
  LET port = _qa_getClientPort()
  DISPLAY "FGLSERVER is:", fgl_getenv("FGLSERVER"), ",FGLSERVER _port is:", port
  LET port = port + 6400
  DISPLAY "FGLSERVER + 6400 port is:", port
  LET ppid = fgl_getenv("META_PPID")
  LET host = fgl_getenv("META_HOST")
  LET myProcId = sfmt("%1:%2",host,fgl_getpid())
  LET name = arg_val(0)

  DISPLAY "name:",name,"ppid:", ppid, ",host:", host
  LET vmmeta = --without meta
      SFMT('Connection {{encoding "UTF-8"} {protocolVersion "102"} {interfaceVersion "110"} {runtimeVersion "3.20.14-2525"} {compression "none"} {encapsulation "1"} {filetransfer "1"} {procIdParent "%1"} {procId "%2"} {frontEndID "%3"} {programName "%4"}}',
          ppid, myProcId, fgl_getenv("_FGLFEID"),name )
  CALL s1.openClientSocket("localhost", port, "u", 0)
  CALL s1.writeNoNL("meta ")
  CALL s1.dataAvailable() RETURNING status --flush
  IF name=="meta" THEN
    DISPLAY "wait with the meta"
    CALL fgl_setenv("META_PPID",myProcId)
    DISPLAY "ppid for meta2 must be:",myProcId
    RUN "fglrun meta2" WITHOUT WAITING
    SLEEP 5
  END IF
  CALL s1.writeLine(vmmeta)
  DISPLAY "did write:meta ",vmmeta
  LET climeta = s1.readLine()
  DISPLAY "climeta:", climeta
  LET om =
      SFMT('om 0 {{an 0 UserInterface 0 {{name "%1"} {text "%2"} {charLengthSemantics "0"} {procId "%3"} {parentProcId "%4"} {dbDate "MDY4/"} {dbCentury "R"} {decimalSeparator "."} {thousandsSeparator ","} {errorLine "-1"} {commentLine "-1"} {formLine "2"} {messageLine "1"} {menuLine "0"} {promptLine "0"} {inputWrap "0"} {fieldOrder "1"} {currentWindow "109"} {focus "0"} {runtimeStatus "interactive"}} {{ActionDefaultList 1 {{fileName "yy"}} {}} {StyleList 61 {{fileName "xx"}} {}} {Window 109 {{name "x"} {posX "0"} {posY "0"} {width "1"} {height "1"}} {{Form 110 {{name "test"} {build "3.20.03"} {width "1"} {height "1"} {formLine "2"}} {{Grid 111 {{width "1"} {height "1"}} {{Label 112 {{text "x"} {posY "0"} {posX "0"} {gridWidth "1"}} {}}}}}}}}}}}',
          name,name,myProcId, ppid)
  CALL s1.writeLine(om)
  LET omNum = 1
  WHILE (resp := s1.readLine()) IS NOT NULL AND NOT s1.isEof()
    --just emit the empty om in case the client wants something
    CALL s1.writeLine(SFMT('om %1 {}', omNum))
    LET omNum = omNum + 1
  END WHILE

END FUNCTION

FUNCTION getHost(procId STRING)
  DEFINE a, b STRING
  DEFINE p INTEGER
  LET p = procId.getIndexOf(":", 1)
  LET b = procId.subString(1, p - 1)
  IF b.getLength() == 0 THEN
    LET b = "localhost"
  END IF
  RETURN b
END FUNCTION

FUNCTION _qa_getClientPort()
  DEFINE a, b STRING
  DEFINE p, ib INTEGER
  LET a = fgl_getenv("FGLSERVER")
  IF a IS NULL THEN
    RETURN 0
  END IF
  LET p = a.getIndexOf(":", 1)
  LET b = a.subString(p + 1, a.getLength())
  LET ib = b
  RETURN ib
END FUNCTION

FUNCTION qa_getAttr(omId, attrName)
  DEFINE omId INT
  DEFINE attrName STRING
  DEFINE value STRING
  DEFINE node om.DomNode
  LET node = _qa_omId2Node(omId)
  LET value = node.getAttribute(attrName)
  RETURN value
END FUNCTION

FUNCTION _qa_omId2Node(omId)
  DEFINE omId INTEGER
  DEFINE node om.DomNode
  DEFINE doc om.DomDocument
  DEFINE idStr STRING
  LET doc = ui.Interface.getDocument()
  IF omId = -1 THEN
    CALL myErr("could not convert id \"" || idStr || "\" to a node")
    RETURN NULL
  END IF
  LET node = doc.getElementById(omId)
  IF node IS NULL THEN
    LET idStr = omId
    CALL myErr("could not convert id \"" || idStr || "\" to a node")
  END IF
  RETURN node
END FUNCTION

FUNCTION extractMetaVar(line STRING, varname STRING, forceFind BOOLEAN)
  DEFINE valueIdx1, valueIdx2 INT
  DEFINE value STRING
  CALL extractMetaVarSub(line, varname, forceFind)
      RETURNING value, valueIdx1, valueIdx2
  RETURN value
END FUNCTION

FUNCTION extractMetaVarSub(
    line STRING, varname STRING, forceFind BOOLEAN)
    RETURNS(STRING, INT, INT)
  DEFINE idx1, idx2, len INT
  DEFINE key, value STRING
  LET key = SFMT('{%1 "', varname)
  LET len = key.getLength()
  LET idx1 = line.getIndexOf(key, 1)
  IF (forceFind == FALSE AND idx1 <= 0) THEN
    RETURN "", 0, 0
  END IF
  MYASSERT(idx1 > 0)
  LET idx2 = line.getIndexOf('"}', idx1 + len)
  IF (forceFind == FALSE AND idx2 < idx1 + len) THEN
    RETURN "", 0, 0
  END IF
  MYASSERT(idx2 > idx1 + len)
  LET value = line.subString(idx1 + len, idx2 - 1)
  CALL log(SFMT("extractMetaVarSub: '%1'='%2'", varname, value))
  RETURN value, idx1 + len, idx2 - 1
END FUNCTION

FUNCTION printStderr(errstr STRING)
  DEFINE ch base.Channel
  LET ch = base.Channel.create()
  CALL ch.openFile("<stderr>", "w")
  CALL ch.writeLine(errstr)
  CALL ch.close()
END FUNCTION

FUNCTION myErr(errstr STRING)
  CALL printStderr(
      SFMT("ERROR:%1 stack:\n%2", errstr, base.Application.getStackTrace()))
  EXIT PROGRAM 1
END FUNCTION

FUNCTION log(s STRING)
  DISPLAY s
END FUNCTION
