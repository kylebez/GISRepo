// This file references code file copied from the following GitHub repository:
// Repository: https://github.com/gadomski/utm
// File: src/lib.rs
// Author: Pete Gadomski

// Additional modifications may have been made to the original code.

use std::env;
use test_utm_converter::to_utm_wgs84_no_zone;

fn main() {
    // Collect command-line arguments
    let args: Vec<String> = env::args().collect();

    // Ensure the correct number of arguments are provided
    if args.len() != 3 {
        eprintln!("Usage: {} <latitude> <longitude>", args[0]);
        std::process::exit(1);
    }

    // Parse arguments
    let latitude: f64 = args[1].parse().expect("Invalid latitude");
    let longitude: f64 = args[2].parse().expect("Invalid longitude");

    // Call the function and print the result
    let result = to_utm_wgs84_no_zone(latitude, longitude);
    let (northing, easting, zone) = result;
    println!("Northing: {}, Easting: {}, Zone: {}", northing, easting, zone);
}


