use test_utm_converter::to_utm_wgs84;

fn main() {
    let result = to_utm_wgs84(41.16547222222222, -96.04787777777777, 14);
    let (northing, easting, zone) = result;
    println!("Northing: {}, Easting: {}, Zone: {}", northing, easting, zone);
}