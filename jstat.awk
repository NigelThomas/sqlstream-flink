BEGIN { FS = " "; last_gc=-1; last_gct=0; last_time=0 }

# Takes output from jstat -gc -t and produces an easier to read summary

{
	if ($1 == "#") {
		# A line which has been added to give context; pass it through
		print($0)
	}
	else if ($1 == "Timestamp") {
		# heading line
		printf("Timestamp,HeapUsedGib,HeapCurrentGib,YGC,YGCT,FGC,FGCT,GCT,DeltaGC%,GC%\n");
	} else {
		time=int($1)
		s0c=$2
		s1c=$3
		s0u=$4
		s1u=$5
		ec=$6
		eu=$7
		oc=$8
		ou=$9
		ygc=$14
		ygct=$15
		fgc=$16
		fgct=$17
		gct=$18

		heapused=(s0u+s1u+eu+ou)/(1024*1024)
		heapcurrent=(s0c+s1c+ec+oc)/(1024*1024)
		gcratio=(time==0)?0:(100*gct)/time

		if (last_gc < fgc+ygc) {
			# there has been some GC activity in prior period
			delta_gc=(ygc+fgc)-((last_gc == -1)?0:last_gc)
			delta_gct=gct-last_gct
			delta_time=time-last_time

			delta_gcratio=(delta_time==0)?0:(delta_gct*100)/delta_time

			printf("%d,%.3f,%.3f,%d,%.2f,%d,%.2f,%.2f,%6.3f%,%6.3f%\n",time,heapused,heapcurrent,ygc,ygct,fgc,fgct,gct,delta_gcratio,gcratio)
			last_gc = fgc+ygc
			last_gct= gct
			last_time=time
		}
	}
}
