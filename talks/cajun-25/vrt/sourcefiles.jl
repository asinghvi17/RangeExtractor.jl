folders = readdir("/Volumes/Anshul's Passport/Copernicus-30m"; join = true) |> x -> filter(y -> isdir(y) && !startswith(".", y), x)
files = [joinpath(folder, splitdir(folder)[end] * ".tif") for folder in folders] # only load main info for now
write("sourcefiles.txt", join(files, '\n'))
