#
# \file digikam.tcl
# 
#
##

package require sqlite3

#
#  Searches in a digikam database for a given name
#
#  Database schema accordiung to digikam4 is assumed.
#  The result is sorted by creation date.
#
#  Supported optional parameters
#    - -command   A user Tcl-Script. The script must accept the following parameters filename name date x y width height
#    - -cnt       Number of images to convert
#  
#
#  \param db    Database handle
#  \param name  Name to search for
#  \param args  Optional parameters
#
##
proc ExportFacesByName { db name args } {
	
	# puts [info level 0]
	
	array set Options [list -command {} -cnt 0]
	foreach {Optname Optvalue} $args {
		set Options($Optname) $Optvalue
	}
	
	set ImagesCoordsDate [db eval "SELECT ImageTagProperties.imageid, value, creationDate FROM ImageTagProperties \
					JOIN ImageInformation ON ImageTagProperties.imageid = ImageInformation.imageid \
					WHERE ImageTagProperties.tagid = (SELECT id FROM Tags WHERE name = '$name') \
					ORDER BY creationDate"]

	set RecordCnt [expr [llength $ImagesCoordsDate] / 3]
	puts [format {Records found: %d} $RecordCnt]

	set Cnt $Options(-cnt)
	foreach {Imageid Geom CreationDate} $ImagesCoordsDate {
		
		#puts "Imageid $Imageid Geom $Geom CreationDate $CreationDate"
		if { $Options(-cnt) && $Cnt < 0 } {
			return
		}
		incr Cnt -1

		lassign [db eval "SELECT album, name             FROM Images           WHERE id = $Imageid"]   Album FName
		lassign [db eval "SELECT albumRoot, relativePath FROM Albums           WHERE id = $Album"]     AlbumRoot RelativePath
		lassign [db eval "SELECT specificPath            FROM AlbumRoots       WHERE id = $AlbumRoot"] SpecificPath
		
		set Filename [format {/home%s%s/%s} $SpecificPath $RelativePath $FName]
		set Ret [regexp {x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"} $Geom -> X Y Width Height]
		
		if { $Options(-command) ne "" } {
			try {
				{*}$Options(-command) $Filename $name $CreationDate $X $Y $Width $Height
			} on error {Result XOptions} {
				puts "$Options(-command) failed."
				puts $Result
			}
		}
	}
}

#
#  Save the selection of an image to a new image.
#
#  Uses the external program convert-im6 to save the selection.
#  Adds a label containing the date.
#
#  Filenames are created by date and a counter. The format is <Year>_<_Month>-<Counter>.
#
#  \param filename    Original filename
#  \param name        Name of the person
#  \param date        Creation dateputs [llength $argv]
#  \param x           x-position of the selection
#  \param y           y-position of the selection
#  \param width       width  of the selection
#  \param height      height of the selection
#
##
proc CreateFace { filename name date x y width height } {
	
	#puts [info level 0]
	
	array set Months [list 00 xx \
	   01 Januar \
	   02 Februar \
	   03 März \
	   04 April \
	   05 Mai \
	   06 Juni \
	   07 Juli \
	   08 August \
	   09 September \
	   10 Oktober \
	   11 November \
	   12 Dezember \
	]
	
	set T     [clock scan $date]
	set M     [clock format $T -format {%m}]
	set Date  [clock format $T -format {%Y_%m}]
	
	set Label $Months($M)
	append Label [clock format $T -format { %Y}]
	
	if { [info exist ::__Date] == 0 } {
		set ::__Date ""
		set ::__DateCnt 1
	}
	
	if { $::__Date ne $date } {
		set ::__DateCnt 1
	}
	
	set Base   [file rootname $filename]
	set Ext    [string tolower [file extension $filename]]
	set Output [format {%s-%s-%02d-mini%s} $name $Date $::__DateCnt $Ext]
		
	set CropSpec [format {%dx%d+%d+%d} $width $height $x $y]
	puts "\"$filename\" -> \"$Output\""
	catch [exec convert-im6 $filename -crop $CropSpec +repage -resize 200x300 t.jpg]
	catch [exec convert-im6 t.jpg -background Khaki label:$Label -gravity Center -append $Output]
}

if { [llength $argv] < 1 } {
	puts "Usage: tclsh digikam.tcl name"
	return
}

set name   [lindex $argv 0]

sqlite db "/home/hae/Bilder/digikam4.db"
ExportFacesByName db $name -command CreateFace


