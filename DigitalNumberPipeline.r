# This script converts DJI H20T Thermal data from *.rjpeg to calibrated *.tif files (while also transfering the metadata, e.g. lat/long coordinates).
# Consider to adopt the humidity, camera-target-distance and emissivity according to your needs.
# The output is directly compatible with Agisoft Metashape or Pix4D
# The script calls DJI Thermal SDK which is available for download here: https://www.dji.com/de/downloads/products/zenmuse-h20-series
# Questions? --> teja_dot_Kattenborn_at_uni_minus_leipzig_dot_de


require(hexView)
require(raster)
require(ijtiff)
require(exifr)

#devtools::install_github("paleolimbot/exifr")

# IMPORTANT: Make sure that you installed Perl on your system. Details see here under 'Installation': https://cran.r-project.org/web/packages/exifr/readme/README.html


### dir where DJI Thermal SDK 'dji_irp.exe' file is located (select appropriate release according to your OS).
# "C:\Program Files\dji_thermal_sdk_v1.6_20240927\utility\bin\windows\release_x64"
sdk_dir = "C:/Program Files/dji_thermal_sdk_v1.6_20240927/utility/bin/windows/release_x64" # change this to your own path

setwd(sdk_dir) # convinient way to set SDK paths across OS systems (path compatibility)

# short version for running commands in terminal
run <- function(x) {
    cat("Running command:", x, "\n")
    shell(x, intern = FALSE, wait = TRUE)
}

### acquisitions / environmental properties:
emissivity = 0.96 # default: 1.0 range: 0.1-1.0 https://royalsocietypublishing.org/doi/pdf/10.1098/rsos.181281 (e.g., average 0.957 for vegetation)
humidity = 38 # default: 70 %  range: 20-100 %
distance = 25 # default: 5 m   range: 1-25 m    # altitude - object height (set to 25 if camera-target-distance > 25 m)


###  dir where your raw *.rpeg thermal images are placed. A output directory will be placed inside this folder.
#in_dir = "C:/Users/serge/Dropbox/Serge Wich/PC/Documents/Downloads/dji_h20t_rpeg_to_tif-main2/dji_h20t_rpeg_to_tif-main/sample_data" # rf 29 %
#the above path did not work because of the empty space perhaps even though the path above also has the empty space
#making the path shorter worked however
in_dir = "C:/ThermalData2/" # Appears to work with or without final slash

# out_dir is the output directory where the converted images will be saved
out_dir = "ir_calib/"
out_dir = paste0(in_dir, "/", out_dir)
dir.create(out_dir)
in_files = list.files(in_dir, full.names = T, pattern = "_T") # "_T" is the DJI H20T thermal image pattern


### calibration/conversion procedure (...could be paralleled)
for(i in seq_along(in_files)){
  
  # Some images may be overexposed. The following lines prevent the loop from stopping in such case (and there will be no putput).
  # Test to reduce the humidty parameter if too many images are missing after the loop.
  tryCatch({
    
    # calibration to celsius
    in_exif = exifr::read_exif(in_files[i])
    in_name = in_files[i]
    out_name = paste0(out_dir, substr(basename(in_files[i]), 0, nchar(basename(in_files[i]))-4), ".raw")
    run(paste0("dji_irp.exe -s ", in_name, " -a measure -o ", out_name, " --measurefmt float32", 
               " --emissivity ", emissivity, " --humidity ", humidity, " --distance ", distance))
    
    # from .raw (hex) to .tif (celsius in float)
    raw_data <- readBin(out_name, "double", size = 4, n = in_exif$ImageWidth*in_exif$ImageHeight)
    image_matrix <- matrix(raw_data, nrow = in_exif$ImageHeight, ncol = in_exif$ImageWidth, byrow = T)
    out_name_tif = paste0(substr(out_name, 0, nchar(out_name)-4), ".tif")
    write_tif(image_matrix, path = out_name_tif, overwrite = TRUE)
    
    # transfer metadata (exif)
    exiftool_call(paste0("-Model=", in_exif$Model[1]), out_name_tif)
    exiftool_call(paste0("-Make=", in_exif$Make[1]), out_name_tif)
    # exiftool_call(paste0("-Orientation=", in_exif$Orientation[1]), out_name_tif)
    # exiftool_call("-Orientation=1", out_name_tif)  # Set Orientation to Normal
    exiftool_call("-Orientation=", out_name_tif)  # Remove the Orientation tag
    exiftool_call(paste0("-FocalLength=", in_exif$FocalLength[1]), out_name_tif)
    exiftool_call(paste0("-FocalLengthIn35mmFormat=", in_exif$FocalLengthIn35mmFormat[1]), out_name_tif)
    exiftool_call(paste0("-DigitalZoomRatio=", in_exif$DigitalZoomRatio[1]), out_name_tif)
    exiftool_call(paste0("-ApertureValue=", in_exif$ApertureValue[1]), out_name_tif)
    exiftool_call(paste0("-GPSAltitude=", in_exif$GPSAltitude[1]), out_name_tif)
    exiftool_call(paste0("-GPSLatitude=", in_exif$GPSLatitude[1]), out_name_tif)
    exiftool_call(paste0("-GPSLongitude=", in_exif$GPSLongitude[1]), out_name_tif)
    exiftool_call(paste0("-GPSLatitudeRef=", in_exif$GPSLatitudeRef[1]), out_name_tif)

    # Print the orientation value to the console
    orientation <- in_exif$Orientation[1]
    cat("Current Orientation:", orientation, "\n")
    
  }, error=function(e){cat("ERROR :",conditionMessage(e), "\n")})
}

### remove temp files
file.remove(list.files(in_dir, recursive = TRUE, full.names = T, pattern = "_original"))
file.remove(list.files(in_dir, recursive = TRUE, full.names = T, pattern = "_T.raw"))

