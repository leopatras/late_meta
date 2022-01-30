%.42f: %.per 
	fglform -M $<

%.42m: %.4gl 
	fglcomp -M $*


MODS=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))

all: $(MODS)

run: all
	fglrun main

fglwebrun:
	git clone https://github.com/FourjsGenero/tool_fglwebrun.git fglwebrun

webrun: all fglwebrun
	FILTER=ALL fglwebrun/fglwebrun main

gdcwebrun: all fglwebrun
	FILTER=ALL GDC=1 fglwebrun/fglwebrun main

fgljp:
	git clone https://github.com/FourjsGenero/tool_fgljp.git fgljp

fgljprun: all fgljp
	fgljp/fgljp -v main

gdcfgljprun: all fgljp
	GDCFGLSERVER=localhost:0 fgljp/fgljp -g -v main

clean:
	rm -f *.42? fglwebrun fgljp
	
