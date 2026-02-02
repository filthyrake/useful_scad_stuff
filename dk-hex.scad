// === NASA-STYLE HEXAGONAL CHAINMAIL v5l - OPTIMIZED ===
// All rings same direction - no alternation
// Performance optimized: uses polyhedron rings instead of hull-spheres

// Grid parameters
hex_count_x = 5;
hex_count_y = 5;

// === MASTER SIZE - Change this to scale everything ===
hex_radius = 6;          // Outer radius (center to vertex)

// === PROPORTIONS (as ratios of hex_radius) ===
// Adjust these to change relative proportions
tile_thickness_ratio = 0.30;    // Thickness of flat hex top
post_radius_ratio = 0.20;       // Radius of center cylinder
post_height_ratio = 1.20;       // How far post extends below tile
cap_radius_ratio = 0.50;        // Radius of the center cap
cap_height_ratio = 0.15;        // Center cap height
ring_major_ratio = 0.40;        // Major radius of torus (ring size)
ring_minor_ratio = 0.11;        // Minor radius (wire thickness)
ring_overhang_ratio = 0.14;    // How far rings extend past hex edge
ring_twist_ratio = 1;        // How much Z variation (helix height)
ring_clearance_ratio = 0.11;    // Print-in-place gap

// Ring tilt (angle - doesn't scale)
ring_tilt = 0;

// === DERIVED DIMENSIONS (auto-calculated from hex_radius) ===
tile_thickness = hex_radius * tile_thickness_ratio;
post_radius = hex_radius * post_radius_ratio;
post_height = hex_radius * post_height_ratio;
cap_radius = hex_radius * cap_radius_ratio;
cap_height = hex_radius * cap_height_ratio;
ring_major_r = hex_radius * ring_major_ratio;
ring_minor_r = hex_radius * ring_minor_ratio;
ring_overhang = hex_radius * ring_overhang_ratio;
ring_twist = hex_radius * ring_twist_ratio;
ring_clearance = hex_radius * ring_clearance_ratio;

hex_apothem = hex_radius * cos(30);
spacing_x = hex_apothem * 2 + ring_clearance;
spacing_y = hex_radius * 1.5 + ring_clearance;
ring_center_dist = post_radius + ring_major_r - ring_minor_r + ring_overhang;

$fn = 32;
ring_segments = 64;
ring_profile_segments = 12;  // Cross-section resolution

// === MODULES ===

module hexagon_2d(radius) {
    polygon([for (i = [0:5]) [radius * cos(60*i + 30), radius * sin(60*i + 30)]]);
}

module hex_tile() {
    linear_extrude(tile_thickness)
        hexagon_2d(hex_radius);
}

module center_post() {
    translate([0, 0, -post_height])
        cylinder(r = post_radius, h = post_height);
}

module center_cap() {
    translate([0, 0, -post_height-(cap_height/2)])
    cylinder(r = cap_radius, h = cap_height);
}

// Optimized twisted ring using polyhedron
// Much faster than hull() of spheres
module twisted_ring_fast() {
    // Generate vertices for a tube following a helical path
    path_segments = ring_segments;
    profile_segments = ring_profile_segments;

    // Vertical scale factor (flattening)
    z_scale = 1;

    // Generate all vertices
    points = [
        for (i = [0 : path_segments - 1])
            let(
                // Angle around the ring
                path_angle = i * 360 / path_segments,
                // Center point on the helix
                cx = ring_major_r * cos(path_angle),
                cy = ring_major_r * sin(path_angle),
                cz = ring_twist * sin(path_angle) / 2,
                // Tangent direction (derivative of helix)
                tx = -sin(path_angle),
                ty = cos(path_angle),
                tz = ring_twist * cos(path_angle) / (2 * ring_major_r),
                // Normalize tangent
                t_len = sqrt(tx*tx + ty*ty + tz*tz),
                tnx = tx/t_len,
                tny = ty/t_len,
                tnz = tz/t_len,
                // Binormal (cross product of tangent and up)
                // Using simplified calculation for ring
                bx = -cos(path_angle),
                by = -sin(path_angle),
                bz = 0,
                // Normal (cross tangent x binormal)
                nx = tny*bz - tnz*by,
                ny = tnz*bx - tnx*bz,
                nz = tnx*by - tny*bx
            )
            for (j = [0 : profile_segments - 1])
                let(
                    // Angle around the cross-section
                    profile_angle = j * 360 / profile_segments,
                    // Offset in the cross-section plane
                    cos_p = cos(profile_angle),
                    sin_p = sin(profile_angle),
                    // Point on cross-section (scaled vertically)
                    px = (cx + ring_minor_r * (cos_p * bx + sin_p * nx)) * 1.1,
                    py = (cy + ring_minor_r * (cos_p * by + sin_p * ny)) * 0.6,
                    pz = (cz + ring_minor_r * (cos_p * bz + sin_p * nz)) * z_scale
                )
                [px, py, pz]
    ];

    // Generate faces connecting the vertices
    faces = [
        // Side faces (quads split into triangles)
        for (i = [0 : path_segments - 1])
            let(
                i_next = (i + 1) % path_segments,
                base_i = i * profile_segments,
                base_next = i_next * profile_segments
            )
            for (j = [0 : profile_segments - 1])
                let(
                    j_next = (j + 1) % profile_segments,
                    // Four corners of the quad
                    v0 = base_i + j,
                    v1 = base_i + j_next,
                    v2 = base_next + j_next,
                    v3 = base_next + j
                )
                // Two triangles per quad
                each [[v0, v1, v2], [v0, v2, v3]]
    ];

    polyhedron(points=points, faces=faces, convexity=4);
}

// Cached version - renders once and reuses
module twisted_ring_cached() {
    render(convexity=4) twisted_ring_fast();
}

module chainmail_hex_tile() {
    union() {
        // Flat hex top
        hex_tile();

        // Central post
        center_post();

        // 6 twisted rings - all same direction
        for (i = [0:5]) {
            rotate([0, 0, i * 60])
            translate([ring_center_dist, 0, -post_height/2])
            rotate([ring_tilt, 0, 0])
                twisted_ring_fast();
        }

        center_cap();
    }
}

// === GRID ASSEMBLY ===

module hex_chainmail_grid() {
    for (row = [0 : hex_count_y - 1]) {
        for (col = [0 : hex_count_x - 1]) {
            x_offset = (row % 2 == 0) ? 0 : hex_apothem + ring_clearance/2;

            translate([col * spacing_x + x_offset, row * spacing_y, post_height])
                chainmail_hex_tile();
        }
    }
}

// === RENDER ===

hex_chainmail_grid();
