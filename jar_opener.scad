// =====================================================================
//  JAR OPENER - odpiralec kozarcev (2 dela: trdo ohisje + mehek TPU vlozek)
//  Ohisje: PETG/PLA     Vlozek: TPU (95A ali mehkejsi)
//
//  Delovanje: pokrovcek se postavi v siroki del solze in z vzvodom potisne
//  v ozji del (klin), kjer se TPU zobje zagrizejo v rob pokrovcka.
//  Koordinate: sredisce sirokega dela odprtine je (0,0), nos klina kaze v +X,
//  rocaj v -X.
//
//  Izvoz STL: render_part = "body_only" -> ohisje
//             render_part = "tpu_only"  -> TPU vlozek
//  Tisk: oba dela lezeca. Vlozek (ima rezo zadaj) rahlo razpri in ga vtisni
//  v utor skozi odprtino; zaklenjen je za ustnicami ohisja (ni potrebno lepilo).
// =====================================================================

// ------------------------- GLAVNI PARAMETRI --------------------------
max_cap_dia   = 85;   // najvecji premer pokrovcka [mm]
min_cap_dia   = 25;   // najmanjsi premer pokrovcka [mm]
total_height  = 16;   // visina modela [mm]
handle_length = 160;  // dolzina rocaja od sredisca glave do konca [mm]
tpu_thickness = 3;    // debelina TPU vlozka (2-4 mm) [mm]
tolerance     = 0.2;  // zracnost med deloma [mm]
render_part   = "assembly";   // "assembly" | "body_only" | "tpu_only"

$fn = 80;             // gladkost krivulj

// ------------------------ DODATNI PARAMETRI --------------------------
cap_clearance    = 1.0;  // dodatna zracnost ob najvecjem pokrovcku (do konic zob)
wedge_half_angle = 28;   // pol-kot klina [deg]
wall             = 6;    // debelina stene ohisja okoli utora [mm]
skin             = 2;    // debelina zgornje/spodnje stene nad utorom [mm]
retain_z         = 2;    // visina zaklepa vlozka za ustnicami [mm]
tooth_pitch      = 3.2;  // razmik med zobmi [mm]
tooth_width      = 1.8;  // sirina V-utora med zobmi [mm]
tooth_depth_k    = 0.55; // globina utorov (delez visine reber)
slit_w           = 1.5;  // reza v vlozku za lazjo vgradnjo [mm]

// ergonomija rocaja
handle_root_d  = 46;   // sirina rocaja ob glavi [mm]
handle_waist_d = 26;   // najozji del (prijem) [mm]
handle_end_d   = 34;   // zakljucna zadebelitev [mm]
fillet_r       = 8;    // zaokrozitev prehoda rocaj-glava [mm]
hang_hole_d    = 10;   // luknja za obesanje (0 = brez) [mm]

// --------------------------- IZPELJANE VREDNOSTI ---------------------
R1  = max_cap_dia/2 + cap_clearance;          // polmer sirokega dela (konice zob)
R0  = min_cap_dia/2;                          // polmer ozkega dela
L   = (R1 - R0) / sin(wedge_half_angle);      // razdalja med sredisci lokov
phi = wedge_half_angle;

tooth_h  = tpu_thickness * 0.5;               // radialna visina reber vlozka
protr    = tooth_h * 0.3;                     // koliko zobje gledajo cez ustnice
lip_back = tooth_h - tolerance;               // zunanji rob ustnic ohisja
pocket_h = total_height - 2*skin;             // visina utora (plosca vlozka)
gap_h    = pocket_h - 2*retain_z;             // visina rebrastega dela
R_out    = R1 + tpu_thickness + tolerance + wall; // zunanji polmer glave

assert(tpu_thickness >= 2 && tpu_thickness <= 4, "tpu_thickness mora biti 2-4 mm");
assert(gap_h > 2, "Povecaj total_height ali zmanjsaj skin/retain_z");
assert(handle_length > R_out + 40, "handle_length je prekratek");

// ------------------------------ 2D OSNOVE ----------------------------
// Obris solze (kontaktna povrsina = konice zob)
module teardrop_2d() { hull() { circle(r = R1); translate([L, 0]) circle(r = R0); } }
// Obris solze, razsirjen navzven za d
module teardrop_off(d) { offset(r = d) teardrop_2d(); }

// Rocaj: koren -> ozji prijem -> zadebelitev na koncu
module handle_2d() {
    x_root  = -R_out * 0.7;
    x_end   = -(handle_length - handle_end_d/2);
    x_waist = x_root + (x_end - x_root) * 0.5;
    hull() { translate([x_root, 0]) circle(d = handle_root_d);
             translate([x_waist,0]) circle(d = handle_waist_d); }
    hull() { translate([x_waist,0]) circle(d = handle_waist_d);
             translate([x_end,  0]) circle(d = handle_end_d); }
}

// Zunanji obris ohisja (glava + rocaj, vbocni koti zaobljeni)
module body_outline_2d() {
    difference() {
        offset(r = -fillet_r) offset(delta = fillet_r)
            union() { teardrop_off(tpu_thickness + tolerance + wall); handle_2d(); }
        if (hang_hole_d > 0)
            translate([-(handle_length - handle_end_d/2), 0]) circle(d = hang_hole_d);
    }
}

// ------------------------------ ZOBJE --------------------------------
// V-utor, ki sega od kontaktne povrsine navzven (lokalno +X)
module groove_at(p, a, depth) {
    translate(p) rotate(a)
        polygon([[-0.05, -tooth_width/2], [depth, 0], [-0.05, tooth_width/2]]);
}

// Vsi rezalniki zob vzdolz obrisa solze (ravna boka + veliki lok + nos)
module teeth_cutters_2d(depth) {
    n_flank = floor((L * cos(phi)) / tooth_pitch);
    p1  = [R1 * sin(phi), R1 * cos(phi)];     // tangentna tocka na velikem loku
    dir = [cos(phi), -sin(phi)];              // smer ravnega boka proti nosu
    for (m = [0, 1]) mirror([0, m, 0])        // oba boka
        for (i = [0 : n_flank - 1])
            groove_at(p1 + (i + 0.5) * tooth_pitch * dir, 90 - phi, depth);
    da1 = tooth_pitch / R1 * 180 / PI;        // veliki lok
    for (a = [90 - phi + da1/2 : da1 : 270 + phi - da1/2])
        groove_at(R1 * [cos(a), sin(a)], a, depth);
    da0 = tooth_pitch / R0 * 180 / PI;        // nos
    for (a = [-(90 - phi) + da0/2 : da0 : (90 - phi) - da0/2])
        groove_at([L, 0] + R0 * [cos(a), sin(a)], a, depth);
}

// ------------------------------ OHISJE -------------------------------
// Radialni prerez (od kontaktne povrsine navzven):
//   [0 .. protr]          odprtina
//   [protr .. lip_back]   ustnice ohisja (zgoraj/spodaj, zunaj rebrastega dela)
//   [lip_back .. tpu+tol] utor za plosco vlozka (visina pocket_h)
module body() {
    difference() {
        linear_extrude(height = total_height) body_outline_2d();
        // 1) odprtina skozi vso visino
        translate([0, 0, -1]) linear_extrude(height = total_height + 2) teardrop_off(protr);
        // 2) reza za rebra vlozka
        translate([0, 0, (total_height - gap_h)/2])
            linear_extrude(height = gap_h) teardrop_off(tooth_h);
        // 3) utor za plosco vlozka (zaklenjen za ustnicami)
        translate([0, 0, skin]) linear_extrude(height = pocket_h)
            difference() { teardrop_off(tpu_thickness + tolerance); teardrop_off(lip_back); }
    }
}

// ----------------------------- TPU VLOZEK ----------------------------
module tpu_ribs_2d() {      // rebrasti kontaktni del z zobmi
    difference() {
        difference() { teardrop_off(tooth_h); teardrop_2d(); }
        teeth_cutters_2d(tooth_h * tooth_depth_k);
    }
}
module tpu_plate_2d() {     // plosca, ki sedi v utoru
    difference() { teardrop_off(tpu_thickness); teardrop_off(tooth_h - 0.01); }
}
module tpu_slit_2d() {      // reza zadaj za lazjo vgradnjo
    translate([-(R1 + tpu_thickness + 1), -slit_w/2]) square([tpu_thickness + 3, slit_w]);
}

module tpu_insert() {
    difference() {
        union() {
            translate([0, 0, skin + tolerance/2])
                linear_extrude(height = pocket_h - tolerance) tpu_plate_2d();
            translate([0, 0, (total_height - (gap_h - tolerance))/2])
                linear_extrude(height = gap_h - tolerance) tpu_ribs_2d();
        }
        translate([0, 0, -1]) linear_extrude(height = total_height + 2) tpu_slit_2d();
    }
}

// ------------------------------- IZBIRA ------------------------------
if (render_part == "assembly") {
    color("DimGray") body();
    color("OrangeRed") tpu_insert();
} else if (render_part == "body_only") {
    body();
} else if (render_part == "tpu_only") {
    translate([0, 0, -(skin + tolerance/2)]) tpu_insert();   // plosca na z=0
} else {
    echo("Neznana vrednost render_part:", render_part);
}
