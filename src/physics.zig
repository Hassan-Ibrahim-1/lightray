const std = @import("std");
const engine = @import("engine");
const math = engine.math;
const Vec3 = math.Vec3;

const root = @import("root");
const Sphere = root.Sphere;
const Cube = root.Cube;
const RigidBody = root.RigidBody;
const ig = engine.ig;

var gravity = Vec3.init(0, -9.8, 0);
var bounce_dampen: f32 = 0.9;

pub const ground_y = -5;

const State = struct {
    outer_sphere: *engine.Actor,
};
var state: State = undefined;

pub fn init(sphere_model: *engine.Model) !void {
    state.outer_sphere = engine.scene().createActor("outer sphere");
    state.outer_sphere.render_item.loadModelData(sphere_model);
    state.outer_sphere.transform.scale = .fromValue(20);
    const dc = &state.outer_sphere.render_item.meshes.items[0].draw_command.?;
    dc.mode = .points;
}

pub fn addToImGui(sphere_count: usize) !void {
    ig.begin("physics");
    defer ig.end();

    ig.text(try std.fmt.allocPrintZ(engine.frameAllocator(), "{} spheres", .{sphere_count}));

    ig.fpsCounter();

    _ = ig.dragFloatEx("bounce dampen", &bounce_dampen, 0.01, null, null);
    _ = ig.dragVec3Ex("gravity", &gravity, 0.01, null, null);

    var radius = state.outer_sphere.transform.scale.x;
    _ = ig.dragFloatEx("radius", &radius, 0.1, null, null);
    state.outer_sphere.transform.scale = .fromValue(radius);
}

pub fn sphereSphereIntersection(
    s1: *const Sphere,
    s2: *const Sphere,
) bool {
    const center_distance = s1.rb.position.sub(s2.rb.position).length();
    return center_distance <= (s1.radius + s2.radius);
}

pub fn cubeSphereIntersection(
    cube: *const Cube,
    sphere: *const Sphere,
) bool {
    const min_corner = Vec3.init(
        cube.rb.position.x - cube.scale.x,
        cube.rb.position.y - cube.scale.y,
        cube.rb.position.z - cube.scale.z,
    );
    const max_corner = Vec3.init(
        cube.rb.position.x + cube.scale.x,
        cube.rb.position.y + cube.scale.y,
        cube.rb.position.z + cube.scale.z,
    );
    const closest_x = @max(min_corner.x, @min(sphere.rb.position.x, max_corner.x));
    const closest_y = @max(min_corner.y, @min(sphere.rb.position.y, max_corner.y));
    const closest_z = @max(min_corner.z, @min(sphere.rb.position.z, max_corner.z));
    const closest_point = Vec3.init(closest_x, closest_y, closest_z);
    const diff = sphere.rb.position.sub(closest_point);
    return diff.length() <= sphere.radius;
}

pub fn cubeCubeIntersection(c1: *const Cube, c2: *const Cube) bool {
    const c1_half_size = c1.scale;
    const c2_half_size = c2.scale;
    return (@abs(c1.rb.position.x - c2.rb.position.x) <= (c1_half_size.x + c2_half_size.x)) and
        (@abs(c1.rb.position.y - c2.rb.position.y) <= (c1_half_size.y + c2_half_size.y)) and
        (@abs(c1.rb.position.z - c2.rb.position.z) <= (c1_half_size.z + c2_half_size.z));
}

pub fn updateRigidBodies(rbs: []*RigidBody) void {
    const dt = engine.deltaTime();
    for (rbs) |rb| {
        if (rb.is_static) continue;
        rb.acceleration = rb.acceleration.add(gravity);
        rb.velocity = rb.velocity.add(rb.acceleration.mulValue(dt));
        rb.position = rb.position.add(rb.velocity.mulValue(dt));
        rb.acceleration = .zero;
    }
}

pub fn resolveCollisions(spheres: []Sphere, cubes: []Cube) void {
    _ = cubes; // autofix
    for (spheres) |*s1| {
        resolveOuterSphereCollision(s1);
        // clampSphereY(s1);
        for (spheres) |*s2| {
            if (s1.eql(s2)) continue;
            if (sphereSphereIntersection(s1, s2)) {
                resolveCollision(&s1.rb, &s2.rb);
                sphereSphereCorrection(s1, s2);
            }
        }
        // for (cubes) |*c| {
        //     if (cubeSphereIntersection(c, s1)) {
        //         resolveCollision(&s1.rb, &c.rb);
        //     }
        // }
    }
    //     for (cubes) |*c1| {
    //         for (cubes) |*c2| {
    //             if (c1.eql(c2)) continue;
    //             if (cubeCubeIntersection(c1, c2)) {
    //                 resolveCollision(&c1.rb, &c2.rb);
    //             }
    //         }
    //     }
}

fn resolveCollision(r1: *RigidBody, r2: *RigidBody) void {
    const n = r2.position.sub(r1.position).normalized();
    const relative_vel = r2.velocity.sub(r1.velocity);
    const vel_along_normal = Vec3.dot(relative_vel, n);

    if (vel_along_normal > 0) return;

    const e = @min(r1.bounce, r2.bounce);
    var j = -(1 + e) * vel_along_normal;
    j /= (1 / r1.mass) + (1 / r2.mass);

    const impulse = n.mulValue(j);
    if (!r1.is_static) {
        r1.velocity = r1.velocity.sub(impulse.divValue(r1.mass));
    }
    if (!r2.is_static) {
        r2.velocity = r2.velocity.add(impulse.divValue(r2.mass));
    }
}

fn sphereSphereCorrection(s1: *Sphere, s2: *Sphere) void {
    const percent = 0.2;
    const slop = 0.01;
    const delta = s2.rb.position.sub(s1.rb.position);
    const pen = (s1.radius - s2.radius) - delta.length();
    const n = delta.normalized();
    const s1_inv_mass = 1 / s1.rb.mass;
    const s2_inv_mass = 1 / s2.rb.mass;
    const x = percent * @max(pen - slop, 0.0) / (s1_inv_mass + s2_inv_mass);
    const correction = n.mulValue(x);
    s1.rb.position = s1.rb.position.sub(correction.mulValue(s1_inv_mass));
    s2.rb.position = s2.rb.position.add(correction.mulValue(s2_inv_mass));
}

pub fn clampSphereY(s: *Sphere) void {
    if (s.rb.position.y - s.radius < ground_y) {
        s.rb.position.y = ground_y + s.radius;
        s.rb.velocity.y = 0;
    }
}

fn resolveOuterSphereCollision(s: *Sphere) void {
    const outer = outerSphere();
    const to_center = s.rb.position.sub(outer.rb.position);
    const dist2 = Vec3.dot(to_center, to_center);
    const max_dist = (outer.radius - s.radius);
    if (dist2 > max_dist * max_dist) {
        const normal = to_center.normalized();
        const n = normal.mulValue(2 * Vec3.dot(s.rb.velocity, normal));
        s.rb.velocity = s.rb.velocity.sub(n);
        s.rb.position = outer.rb.position.add(normal.mulValue(max_dist));
        s.rb.velocity = s.rb.velocity.mulValue(bounce_dampen);
    }
}

fn outerSphere() Sphere {
    const radius = state.outer_sphere.transform.scale.x;
    var s = Sphere.zero;
    s.radius = radius;
    s.rb.position = state.outer_sphere.transform.position;
    return s;
}
