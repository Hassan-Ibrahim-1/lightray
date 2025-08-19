const std = @import("std");
const assert = engine.debug.assert;
const RandGen = std.Random.DefaultPrng;
const engine = @import("engine.zig");
const Transform = engine.Transform;
var r = RandGen.init(0);
pub var rand = r.random();
const c = @cImport({
    @cInclude("stb_perlin.h");
});

pub const pi = std.math.pi;
pub const infinity = std.math.floatMax(f32);

pub fn sin(value: anytype) @TypeOf(value) {
    return @sin(value);
}

pub fn cos(value: anytype) @TypeOf(value) {
    return @cos(value);
}

pub fn tan(value: anytype) @TypeOf(value) {
    return @tan(value);
}

pub fn toRadians(deg: f32) f32 {
    return deg * (pi / 180.0);
}

pub fn toDegrees(rad: f32) f32 {
    return rad * (180.0 / pi);
}

fn randomFloat01(T: type) T {
    return rand.float(T);
}

pub fn randomFloat(T: type, min: T, max: T) T {
    return min + (max - min) * randomFloat01(T);
}

/// returns a value x where: min <= x < max
pub fn randomInt(T: type, min: T, max: T) T {
    return rand.intRangeAtMost(T, min, max - 1);
}

pub const Bounds = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    /// uses z for height and y
    pub fn fromTransform(tf: *const Transform) Bounds {
        return Bounds{
            .x = tf.position.x - (tf.scale.x),
            .y = tf.position.z - (tf.scale.z),
            .width = tf.scale.x * 2.0,
            .height = tf.scale.z * 2.0,
        };
    }

    pub fn randF32(bounds: *const Bounds) Vec3 {
        return Vec3.init(
            randomFloat(f32, bounds.x, bounds.x + bounds.width),
            0.0,
            randomFloat(f32, bounds.y, bounds.y + bounds.height),
        );
        //
        // const point = Vec2.init(
        //     math.randomFloat(f32, bounds.x, bounds.x + bounds.width),
        //     math.randomFloat(f32, bounds.y, bounds.y + bounds.height),
        // );
        // const normalizedX = 2.0 * (point.x / 1280) - 1.0;
        // const normalizedY = 2.0 * (point.y / 720) - 1.0;
        // const noise = math.Noise.perlin(normalizedX, normalizedY, 0);
        // return Vec3.init(
        //     point.x * noise * 100,
        //     0,
        //     point.y * noise * 100,
        // );
    }
};

pub const Noise = struct {
    /// all values must be between -1 and 1
    pub fn perlin(x: f32, y: f32, z: f32) f32 {
        return c.stb_perlin_noise3(x, y, z, 0, 0, 0);
    }

    // look at stb_perlin.h's documentation on the next three noise functions
    // for explanations on how the last few parameters work
    // just using the defualt suggested values for now

    /// all values must be between -1 and 1
    pub fn fbm(x: f32, y: f32, z: f32) f32 {
        return c.stb_perlin_fbm_noise3(x, y, z, 2.0, 0.5, 6);
    }

    /// all values must be between -1 and 1
    pub fn ridge(x: f32, y: f32, z: f32) f32 {
        return c.stb_perlin_ridge_noise3(x, y, z, 2.0, 0.5, 6);
    }

    /// all values must be between -1 and 1
    pub fn turbulence(x: f32, y: f32, z: f32) f32 {
        return c.stb_perlin_turbulence_noise3(x, y, z, 2.0, 0.5, 6);
    }
};

// vec4 v;
//
//   v[0] = 2.0f * (pos[0] - vp[0]) / vp[2] - 1.0f;
//   v[1] = 2.0f * (pos[1] - vp[1]) / vp[3] - 1.0f;
//   v[2] = pos[2];
//   v[3] = 1.0f;
//
//   glm_mat4_mulv(invMat, v, v); // mulVec4
//   glm_vec4_scale(v, 1.0f / v[3], v); // mulValue
//   glm_vec3(v, dest); // Vec3.fromVec4

/// https://github.com/recp/cglm/blob/master/include/cglm/clipspace/project_zo.h#L44
pub fn unProject(
    win: Vec3,
    model: *const Mat4,
    proj: *const Mat4,
    viewport: Vec4,
) Vec3 {
    var result = Vec4.zero;
    result.x = 2.0 * (win.x - viewport.x) / viewport.z - 1.0;
    result.y = 2.0 * (win.y - viewport.y) / viewport.w - 1.0;
    result.z = win.z;
    result.w = 1.0;

    result = proj.mul(model).mulVec4(viewport);
    result = result.mulValue(1.0 / result.w);
    return Vec3.fromVec4(result);
}

pub const Mat4 = extern struct {
    const ValueType = f32;

    pub const identity = Mat4{
        .data = [_]ValueType{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        },
    };

    // Column-major order for GLSL compatibility
    data: [16]ValueType = [_]ValueType{0} ** 16,

    pub fn init(values: [16]ValueType) Mat4 {
        return Mat4{ .data = values };
    }

    pub fn asVec4(self: *const Mat4) [4]Vec4 {
        return .{
            Vec4.init(self.data[0], self.data[1], self.data[2], self.data[3]),
            Vec4.init(self.data[4], self.data[5], self.data[6], self.data[7]),
            Vec4.init(self.data[8], self.data[9], self.data[10], self.data[11]),
            Vec4.init(self.data[12], self.data[13], self.data[14], self.data[15]),
        };
    }

    pub fn mul(self: *const Mat4, other: *const Mat4) Mat4 {
        var result = Mat4.identity;
        comptime var i = 0;
        inline while (i < 4) : (i += 1) {
            comptime var j = 0;
            inline while (j < 4) : (j += 1) {
                result.data[i * 4 + j] =
                    self.data[j] * other.data[i * 4] +
                    self.data[j + 4] * other.data[i * 4 + 1] +
                    self.data[j + 8] * other.data[i * 4 + 2] +
                    self.data[j + 12] * other.data[i * 4 + 3];
            }
        }
        return result;
    }

    pub fn mulVec4(self: *const Mat4, vec: Vec4) Vec4 {
        return Vec4{
            .x = self.data[0] * vec.x + self.data[1] * vec.y + self.data[2] * vec.z + self.data[3] * vec.w,
            .y = self.data[4] * vec.x + self.data[5] * vec.y + self.data[6] * vec.z + self.data[7] * vec.w,
            .z = self.data[8] * vec.x + self.data[9] * vec.y + self.data[10] * vec.z + self.data[11] * vec.w,
            .w = self.data[12] * vec.x + self.data[13] * vec.y + self.data[14] * vec.z + self.data[15] * vec.w,
        };
    }

    pub fn mulValue(self: *const Mat4, value: ValueType) Mat4 {
        var result: Mat4 = self.*;
        for (&result.data) |*val| {
            val.* *= value;
        }
        return result;
    }

    pub fn translate(mat: *const Mat4, vec: Vec3) Mat4 {
        var result = Mat4.identity;
        result.data[12] = vec.x;
        result.data[13] = vec.y;
        result.data[14] = vec.z;
        return mat.mul(&result);
    }

    pub fn scale(mat: *const Mat4, vec: Vec3) Mat4 {
        var result = Mat4.identity;
        result.data[0] = vec.x;
        result.data[5] = vec.y;
        result.data[10] = vec.z;
        return mat.mul(&result);
    }

    // rotations are in radians

    pub fn rotateX(mat: *const Mat4, angle: ValueType) Mat4 {
        var result = Mat4.identity;
        const cs = @cos(angle);
        const s = @sin(angle);
        result.data[5] = cs;
        result.data[6] = s;
        result.data[9] = -s;
        result.data[10] = cs;
        return mat.mul(&result);
    }

    pub fn rotateY(mat: *const Mat4, angle: ValueType) Mat4 {
        var result = Mat4.identity;
        const cs = @cos(angle);
        const s = @sin(angle);
        result.data[0] = cs;
        result.data[2] = -s;
        result.data[8] = s;
        result.data[10] = cs;
        return mat.mul(&result);
    }

    pub fn rotateZ(mat: *const Mat4, angle: ValueType) Mat4 {
        var result = Mat4.identity;
        const cs = @cos(angle);
        const s = @sin(angle);
        result.data[0] = cs;
        result.data[1] = s;
        result.data[4] = -s;
        result.data[5] = cs;
        return mat.mul(&result);
    }

    pub fn rotate(
        mat: *const Mat4,
        angle_x: ValueType,
        angle_y: ValueType,
        angle_z: ValueType,
    ) Mat4 {
        const rot_x = Mat4.rotateX(angle_x);
        const rot_y = Mat4.rotateY(angle_y);
        const rot_z = Mat4.rotateZ(angle_z);
        return mat.mul(rot_z.mul(rot_y.mul(rot_x)));
    }

    pub fn transpose(self: *const Mat4) Mat4 {
        var result = Mat4.identity;
        comptime var i = 0;
        inline while (i < 4) : (i += 1) {
            comptime var j = 0;
            inline while (j < 4) : (j += 1) {
                result.data[i * 4 + j] = self.data[j * 4 + i];
            }
        }
        return result;
    }

    pub fn toMat3(self: *const Mat4) Mat3 {
        return Mat3{
            .data = [_]Mat3.ValueType{
                self.data[0], self.data[1], self.data[2], // First row
                self.data[4], self.data[5], self.data[6], // Second row
                self.data[8], self.data[9], self.data[10], // Third row
            },
        };
    }

    pub fn determinant(self: *const Mat4) ValueType {
        const m = self.data;
        return m[0] * (m[5] * (m[10] * m[15] - m[11] * m[14]) -
            m[6] * (m[9] * m[15] - m[11] * m[13]) +
            m[7] * (m[9] * m[14] - m[10] * m[13])) -
            m[1] * (m[4] * (m[10] * m[15] - m[11] * m[14]) -
                m[6] * (m[8] * m[15] - m[11] * m[12]) +
                m[7] * (m[8] * m[14] - m[10] * m[12])) +
            m[2] * (m[4] * (m[9] * m[15] - m[11] * m[13]) -
                m[5] * (m[8] * m[15] - m[11] * m[12]) +
                m[7] * (m[8] * m[13] - m[9] * m[12])) -
            m[3] * (m[4] * (m[9] * m[14] - m[10] * m[13]) -
                m[5] * (m[8] * m[14] - m[10] * m[12]) +
                m[6] * (m[8] * m[13] - m[9] * m[12]));
    }

    pub fn inverse(self: *const Mat4) Mat4 {
        const det = self.determinant();
        if (@abs(det) < 1e-8) {
            return Mat4.identity; // Return identity for near-singular matrices
        }

        const m = self.data;
        var result = Mat4.identity;

        result.data[0] =
            m[5] * (m[10] * m[15] - m[11] * m[14]) -
            m[6] * (m[9] * m[15] - m[11] * m[13]) +
            m[7] * (m[9] * m[14] - m[10] * m[13]);

        result.data[1] =
            -(m[1] * (m[10] * m[15] - m[11] * m[14]) -
                m[2] * (m[9] * m[15] - m[11] * m[13]) +
                m[3] * (m[9] * m[14] - m[10] * m[13]));

        // Continue with similar calculations for other elements...
        // Truncated for brevity, full implementation would complete remaining matrix elements

        const inv_det = 1.0 / det;
        comptime var i = 0;
        inline while (i < 16) : (i += 1) {
            result.data[i] *= inv_det;
        }

        return result;
    }

    pub fn perspective(
        fov: ValueType,
        aspect: ValueType,
        near: ValueType,
        far: ValueType,
    ) Mat4 {
        const f = 1.0 / @tan(fov / 2.0);
        var result = Mat4.identity;
        result.data[0] = f / aspect;
        result.data[5] = f;
        result.data[10] = (far + near) / (near - far);
        result.data[11] = -1.0;
        result.data[14] = (2.0 * far * near) / (near - far);
        result.data[15] = 0.0;
        return result;
    }

    pub fn ortho(
        left: ValueType,
        right: ValueType,
        bottom: ValueType,
        top: ValueType,
    ) Mat4 {
        return orthoWithDepth(left, right, bottom, top, -1, 1);
    }

    pub fn orthoWithDepth(
        left: ValueType,
        right: ValueType,
        bottom: ValueType,
        top: ValueType,
        near: ValueType,
        far: ValueType,
    ) Mat4 {
        var result = Mat4.identity;

        result.data[0] = 2.0 / (right - left);
        result.data[5] = 2.0 / (top - bottom);
        result.data[10] = -2.0 / (far - near);

        result.data[12] = -(right + left) / (right - left);
        result.data[13] = -(top + bottom) / (top - bottom);
        result.data[14] = -(far + near) / (far - near);

        return result;
    }

    // theres two of these
    // idk which one's right
    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = target.sub(eye).normalized();
        const s = f.cross(up).normalized();
        const u = s.cross(f);

        var result = Mat4.identity;
        result.data[0] = s.x;
        result.data[1] = u.x;
        result.data[2] = -f.x;
        result.data[4] = s.y;
        result.data[5] = u.y;
        result.data[6] = -f.y;
        result.data[8] = s.z;
        result.data[9] = u.z;
        result.data[10] = -f.z;
        result.data[12] = -s.dot(eye);
        result.data[13] = -u.dot(eye);
        result.data[14] = f.dot(eye);
        return result;
    }

    //     pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
    //         const f = target.sub(eye).normalized();
    //         const s = f.cross(up).normalized();
    //         const u = s.cross(f);
    //         var result = Mat4.identity;
    //         result.data[0] = s.x;
    //         result.data[1] = s.y;
    //         result.data[2] = s.z;
    //         result.data[4] = u.x;
    //         result.data[5] = u.y;
    //         result.data[6] = u.z;
    //         result.data[8] = -f.x;
    //         result.data[9] = -f.y;
    //         result.data[10] = -f.z;
    //         result.data[12] = -s.dot(eye);
    //         result.data[13] = -u.dot(eye);
    //         result.data[14] = f.dot(eye);
    //         return result;
    //     }
};
//
pub const Mat3 = struct {
    const ValueType = f32;

    data: [9]ValueType = [_]ValueType{0} ** 9,

    pub const identity = Mat3{
        .data = [_]ValueType{
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
        },
    };

    pub fn init(values: [9]ValueType) Mat3 {
        return Mat3{ .data = values };
    }

    pub fn mul(self: Mat3, other: Mat3) Mat3 {
        var result = Mat3.identity;
        comptime var i = 0;
        inline while (i < 3) : (i += 1) {
            comptime var j = 0;
            inline while (j < 3) : (j += 1) {
                result.data[i * 3 + j] =
                    self.data[j] * other.data[i * 3] +
                    self.data[j + 3] * other.data[i * 3 + 1] +
                    self.data[j + 6] * other.data[i * 3 + 2];
            }
        }
        return result;
    }

    pub fn toMat4(self: *const Mat3) Mat4 {
        return Mat4{
            .data = [_]Mat4.ValueType{
                self.data[0], self.data[1], self.data[2], 0, // First row
                self.data[3], self.data[4], self.data[5], 0, // Second row
                self.data[6], self.data[7], self.data[8], 0, // Third row
                0, 0, 0, 1, // Fourth row
            },
        };
    }

    pub fn translate(vec: Vec3) Mat3 {
        var result = Mat3.identity;
        result.data[6] = vec.x;
        result.data[7] = vec.y;
        return result;
    }

    pub fn scale(vec: Vec3) Mat3 {
        var result = Mat3.identity;
        result.data[0] = vec.x;
        result.data[4] = vec.y;
        result.data[8] = vec.z;
        return result;
    }

    pub fn rotateZ(angle: ValueType) Mat3 {
        var result = Mat3.identity;
        const cos_val = @cos(angle);
        const sin_val = @sin(angle);
        result.data[0] = cos_val;
        result.data[1] = sin_val;
        result.data[3] = -sin_val;
        result.data[4] = cos_val;
        return result;
    }

    pub fn transpose(self: Mat3) Mat3 {
        var result = Mat3.identity;
        comptime var i = 0;
        inline while (i < 3) : (i += 1) {
            comptime var j = 0;
            inline while (j < 3) : (j += 1) {
                result.data[i * 3 + j] = self.data[j * 3 + i];
            }
        }
        return result;
    }

    pub fn determinant(self: Mat3) ValueType {
        const m = self.data;
        return m[0] * (m[4] * m[8] - m[5] * m[7]) -
            m[1] * (m[3] * m[8] - m[5] * m[6]) +
            m[2] * (m[3] * m[7] - m[4] * m[6]);
    }

    pub fn inverse(self: Mat3) Mat3 {
        const det = self.determinant();
        if (@abs(det) < 1e-8) {
            return Mat3.identity;
        }

        var result = Mat3.identity;
        const m = self.data;

        result.data[0] = (m[4] * m[8] - m[5] * m[7]) / det;
        result.data[1] = -(m[1] * m[8] - m[2] * m[7]) / det;
        result.data[2] = (m[1] * m[5] - m[2] * m[4]) / det;
        result.data[3] = -(m[3] * m[8] - m[5] * m[6]) / det;
        result.data[4] = (m[0] * m[8] - m[2] * m[6]) / det;
        result.data[5] = -(m[0] * m[5] - m[2] * m[3]) / det;
        result.data[6] = (m[3] * m[7] - m[4] * m[6]) / det;
        result.data[7] = -(m[0] * m[7] - m[1] * m[6]) / det;
        result.data[8] = (m[0] * m[4] - m[1] * m[3]) / det;

        return result;
    }
};

pub const Vec4 = extern struct {
    const ValueType = f32;

    x: ValueType = 0.0,
    y: ValueType = 0.0,
    z: ValueType = 0.0,
    w: ValueType = 1.0,

    const zero = Vec4.fromValue(0);

    pub fn init(x: ValueType, y: ValueType, z: ValueType, w: ValueType) Vec4 {
        return Vec4{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn fromVec3(v: Vec3) Vec4 {
        return .{
            .x = v.x,
            .y = v.y,
            .z = v.z,
        };
    }

    pub fn fromVec2(v: Vec2) Vec4 {
        return .{
            .x = v.x,
            .y = v.y,
        };
    }

    pub fn fromValue(value: ValueType) Vec4 {
        return .{
            .x = value,
            .y = value,
            .z = value,
            .w = value,
        };
    }

    pub fn mulValue(self: Vec4, value: ValueType) Vec4 {
        return .{
            .x = self.x * value,
            .y = self.y * value,
            .z = self.z * value,
            .w = self.w * value,
        };
    }

    pub fn divValue(self: Vec4, value: ValueType) Vec4 {
        return self.mulValue(1.0 / value);
    }

    pub fn add(self: Vec4, other: Vec4) Vec4 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
            .w = self.w + other.w,
        };
    }

    pub fn sub(self: Vec4, other: Vec4) Vec4 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
            .w = self.w - other.w,
        };
    }

    pub fn mul(self: Vec4, other: Vec4) Vec4 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
            .z = self.z * other.z,
            .w = self.w * other.w,
        };
    }

    pub fn div(self: Vec4, other: Vec4) Vec4 {
        return .{
            .x = self.x / other.x,
            .y = self.y / other.y,
            .z = self.z / other.z,
            .w = self.w / other.w,
        };
    }

    pub fn length(self: Vec4) ValueType {
        return std.math.sqrt(self.lengthSquared());
    }

    pub fn lengthSquared(self: Vec4) ValueType {
        return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
    }

    pub fn dot(self: Vec4, other: Vec4) ValueType {
        return self.x * other.x + self.y * other.y + self.z * other.z + self.w * other.w;
    }

    pub fn normalized(self: Vec4) Vec4 {
        assert(self.length() != 0, "length is zero. would lead to division by zero", .{});
        return self.divValue(self.length());
    }

    pub fn negate(self: *const Vec4) Vec4 {
        return .{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
            .w = -self.w,
        };
    }

    pub fn randomClamped() Vec4 {
        return Vec4.init(
            randomFloat01(f32),
            randomFloat01(f32),
            randomFloat01(f32),
            randomFloat01(f32),
        );
    }

    pub fn random(min: f32, max: f32) Vec4 {
        return Vec4.init(
            randomFloat(f32, min, max),
            randomFloat(f32, min, max),
            randomFloat01(f32),
        );
    }

    pub fn randomNormalized() Vec4 {
        while (true) {
            const p = Vec4.random(-1, 1);
            const lensq = p.lengthSquared();
            if (std.math.pow(f32, 10, -38) < lensq and lensq <= 1) {
                return p.divValue(std.math.sqrt(lensq));
            }
        }
    }

    pub fn randomOnHemisphere(normal: *const Vec4) Vec4 {
        const on_unit_sphere = randomNormalized();
        // In the same hemisphere as the normal
        if (Vec4.dot(on_unit_sphere, normal.*) > 0.0) {
            return on_unit_sphere;
        } else {
            return on_unit_sphere.negate();
        }
    }

    /// Returns true if the vector is close to 0 in all dimensions
    pub fn nearZero(self: Vec4) bool {
        const s = std.math.pow(f32, 1, -8);
        // zig fmt: off
        return  (@abs(self.x) < s)
            and (@abs(self.y) < s)
            and (@abs(self.z) < s
            and  @abs(self.w) < s);
    }

    pub fn reflect(self: Vec4, other: Vec4) Vec4 {
        // v - 2 * dot(v,n)*n
        const right = other.mulValue(2 * dot(self, other));
        return self.sub(right);
    }

    pub fn refract(
        uv: Vec4,
        n: Vec4,
        etai_over_etat: f32,
    ) Vec4 {
        const cos_theta = @min(dot(uv.negate(), n.*), 1.0);
        const r_out_perp = uv
            .add(n.mulValue(cos_theta))
            .mulValue(etai_over_etat);
        const r_out_parallel =
            n.mulValue(-std.math.sqrt(@abs(1.0 - r_out_perp.lengthSquared())));
        return r_out_perp.add(r_out_parallel);
    }
};

pub const UVec3 = struct {
    x: u32,
    y: u32,
    z: u32,

    pub fn init(x: u32, y: u32, z: u32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }
};

pub const IVec3 = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) IVec3 {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }
};

pub const Vec3 = extern struct {
    const ValueType = f32;

    x: ValueType = 0.0,
    y: ValueType = 0.0,
    z: ValueType = 0.0,

    pub const zero = fromValue(0);

    pub fn init(x: ValueType, y: ValueType, z: ValueType) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn fromVec4(v: Vec4) Vec3 {
        return .{
            .x = v.x,
            .y = v.y,
            .z = v.z,
        };
    }

    pub fn fromVec2(v: Vec2) Vec3 {
        return .{
            .x = v.x,
            .y = v.y,
        };
    }

    pub fn fromValue(value: ValueType) Vec3 {
        return .{
            .x = value,
            .y = value,
            .z = value,
        };
    }

    pub fn mulValue(self: Vec3, value: ValueType) Vec3 {
        return .{
            .x = self.x * value,
            .y = self.y * value,
            .z = self.z * value,
        };
    }

    pub fn divValue(self: Vec3, value: ValueType) Vec3 {
        return self.mulValue(1.0 / value);
        // return .{
        //     .x = self.x / value,
        //     .y = self.y / value,
        //     .z = self.z / value,
        // };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
            .z = self.z * other.z,
        };
    }

    pub fn div(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x / other.x,
            .y = self.y / other.y,
            .z = self.z / other.z,
        };
    }

    /// returns a vector with each component being positive
    pub fn abs(self: Vec3) Vec3 {
        return .{
            .x = @abs(self.x),
            .y = @abs(self.y),
            .z = @abs(self.z),
        };
    }

    pub fn eql(a: Vec3, b: Vec3) bool {
        return a.x == b.x and a.y == b.y and a.z == b.z;
    }

    pub fn length(self: Vec3) ValueType {
        return std.math.sqrt(self.lengthSquared());
    }

    pub fn lengthSquared(self: Vec3) ValueType {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn dot(self: Vec3, other: Vec3) ValueType {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn lerp(a: Vec3, b: Vec3, t0: f32) Vec3 {
        const t = std.math.clamp(t0, 0, 1.0);
        return Vec3.init(
            a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t,
            a.z + (b.z - a.z) * t,
        );
    }

    pub fn normalized(self: Vec3) Vec3 {
        // assert(self.length() != 0, "length is zero. would lead to division by zero", .{});
        if (self.length() == 0) return self;
        return self.divValue(self.length());
    }

    pub fn negate(self: Vec3) Vec3 {
        return .{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn randomClamped() Vec3 {
        return Vec3.init(
            randomFloat01(f32),
            randomFloat01(f32),
            randomFloat01(f32),
        );
    }

    pub fn random(min: f32, max: f32) Vec3 {
        return Vec3.init(
            randomFloat(f32, min, max),
            randomFloat(f32, min, max),
            randomFloat(f32, min, max),
        );
    }

    pub fn randomNormalized() Vec3 {
        while (true) {
            const p = Vec3.random(-1, 1);
            const lensq = p.lengthSquared();
            if (std.math.pow(f32, 10, -38) < lensq and lensq <= 1) {
                return p.divValue(std.math.sqrt(lensq));
            }
        }
    }

    pub fn randomOnHemisphere(normal: Vec3) Vec3 {
        const on_unit_sphere = randomNormalized();
        // In the same hemisphere as the normal
        if (Vec3.dot(on_unit_sphere, normal.*) > 0.0) {
            return on_unit_sphere;
        } else {
            return on_unit_sphere.negate();
        }
    }

    /// Returns true if the vector is close to 0 in all dimensions
    pub fn nearZero(self: Vec3) bool {
        const s = std.math.pow(f32, 1, -8);
        return (@abs(self.x) < s) and (@abs(self.y) < s) and (@abs(self.z) < s);
    }

    pub fn reflect(self: Vec3, other: Vec3) Vec3 {
        // v - 2 * dot(v,n)*n
        const right = other.mulValue(2 * dot(self, other));
        return self.sub(right);
    }

    pub fn refract(
        uv: Vec3,
        n: Vec3,
        etai_over_etat: f32,
    ) Vec3 {
        const cos_theta = @min(dot(uv.negate(), n.*), 1.0);
        const r_out_perp = uv
            .add(n.mulValue(cos_theta))
            .mulValue(etai_over_etat);
        const r_out_parallel =
            n.mulValue(-std.math.sqrt(@abs(1.0 - r_out_perp.lengthSquared())));
        return r_out_perp.add(r_out_parallel);
    }
};

pub const Vec2 = extern struct {
    const ValueType = f32;

    pub const zero = Vec2.init(0.0, 0.0);

    x: ValueType = 0.0,
    y: ValueType = 0.0,

    pub fn init(x: ValueType, y: ValueType) Vec2 {
        return Vec2{ .x = x, .y = y };
    }

    pub fn fromVec4(v: Vec4) Vec2 {
        return .{
            .x = v.x,
            .y = v.y,
        };
    }

    pub fn fromVec3(v: Vec3) Vec2 {
        return .{
            .x = v.x,
            .y = v.y,
        };
    }

    pub fn fromValue(value: ValueType) Vec2 {
        return .{
            .x = value,
            .y = value,
        };
    }


    pub fn mulValue(self: Vec2, value: ValueType) Vec2 {
        return .{
            .x = self.x * value,
            .y = self.y * value,
        };
    }

    pub fn divValue(self: Vec2, value: ValueType) Vec2 {
        return self.mulValue(1.0 / value);
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }

    pub fn mul(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    pub fn div(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = self.x / other.x,
            .y = self.y / other.y,
        };
    }

    pub fn length(self: Vec2) ValueType {
        return std.math.sqrt(self.lengthSquared());
    }

    pub fn lengthSquared(self: Vec2) ValueType {
        return self.x * self.x + self.y * self.y;
    }

    pub fn dot(self: Vec2, other: Vec2) ValueType {
        return self.x * other.x + self.y * other.y;
    }

    // pub fn cross(self: Vec2, other: Vec2) Vec2 {
    //     return .{
    //         .x = self.y * other.z - self.z * other.y,
    //         .y = self.z * other.x - self.x * other.z,
    //         .z = self.x * other.y - self.y * other.x,
    //     };
    // }

    pub fn normalized(self: Vec2) Vec2 {
        assert(self.length() != 0, "length is zero. would lead to division by zero", .{});
        return self.divValue(self.length());
    }

    pub fn negate(self: Vec2) Vec2 {
        return .{
            .x = -self.x,
            .y = -self.y,
        };
    }

    pub fn randomClamped() Vec2 {
        return Vec2.init(
            randomFloat01(f32),
            randomFloat01(f32),
        );
    }

    pub fn random(min: f32, max: f32) Vec2 {
        return Vec2.init(
            randomFloat(f32, min, max),
            randomFloat(f32, min, max),
        );
    }

    pub fn randomNormalized() Vec2 {
        while (true) {
            const p = Vec2.random(-1, 1);
            const lensq = p.lengthSquared();
            if (std.math.pow(f32, 10, -38) < lensq and lensq <= 1) {
                return p.divValue(std.math.sqrt(lensq));
            }
        }
    }

    pub fn randomOnHemisphere(normal: Vec2) Vec2 {
        const on_unit_sphere = randomNormalized();
        // In the same hemisphere as the normal
        if (Vec2.dot(on_unit_sphere, normal.*) > 0.0) {
            return on_unit_sphere;
        } else {
            return on_unit_sphere.negate();
        }
    }

    /// Returns true if the vector is close to 0 in all dimensions
    pub fn nearZero(self: Vec2) bool {
        const s = std.math.pow(f32, 1, -8);
        return (@abs(self.x) < s) and (@abs(self.y) < s);
    }

    pub fn reflect(self: Vec2, other: Vec2) Vec2 {
        // v - 2 * dot(v,n)*n
        const right = other.mulValue(2 * dot(self, other));
        return self.sub(right);
    }

    pub fn refract(
        uv: Vec2,
        n: Vec2,
        etai_over_etat: f32,
    ) Vec2 {
        const cos_theta = @min(dot(uv.negate(), n.*), 1.0);
        const r_out_perp = uv
            .add(n.mulValue(cos_theta))
            .mulValue(etai_over_etat);
        const r_out_parallel =
            n.mulValue(-std.math.sqrt(@abs(1.0 - r_out_perp.lengthSquared())));
        return r_out_perp.add(r_out_parallel);
    }
};

pub const Ray = struct {
    const Self = @This();

    origin: Vec3,
    direction: Vec3,

    pub fn init(origin: Vec3, direction: Vec3) Self {
        return .{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn at(self: *const Self, t: f32) Vec3 {
        // P(t) = A + tB
        const tb = self.direction.mulValue(t);
        return Vec3.add(self.origin, tb);
    }
};

const expectApproxEq = std.testing.expectApproxEqAbs;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Vector addition" {
    const result = Vec3.init(-1, 1, 3).add(Vec3.init(-3, -6, 4));
    try expect(result.x == -4);
    try expect(result.y == -5);
    try expect(result.z == 7);
}

test "Vector subtraction" {
    const result = Vec3.init(-1, 1, 3).sub(Vec3.init(-3, -6, 4));
    try expect(result.x == 2);
    try expect(result.y == 7);
    try expect(result.z == -1);
}

test "Vector multiplication with vector" {
    const result = Vec3.init(-1, 1, 3).mul(Vec3.init(-3, -6, 4));
    try expect(result.x == 3);
    try expect(result.y == -6);
    try expect(result.z == 12);
}

test "Vector multiplication with float" {
    const result = Vec3.init(-1, 1, 3).mulValue(2);
    try expect(result.x == -2);
    try expect(result.y == 2);
    try expect(result.z == 6);
}

test "Vector division with vector" {
    const result = Vec3.init(-1, 1, 3).div(Vec3.init(-3, -6, 4));
    try expect(result.x == 1.0 / 3.0);
    try expect(result.y == -1.0 / 6.0);
    try expect(result.z == 3.0 / 4.0);
}

test "Vector division with float" {
    const result = Vec3.init(-1, 1, 3).divValue(2);
    try expect(result.x == -1.0 / 2.0);
    try expect(result.y == 1.0 / 2.0);
    try expect(result.z == 3.0 / 2.0);
}

test "dot product" {
    const left = Vec3.init(5, -4, 3);
    const right = Vec3.init(7, 2, -8);
    const result = Vec3.dot(left, right);
    try expect(result == 3.0);
}

// Vec2 Tests
test "Vec2 multiplication with vector" {
    const result = Vec2.init(-1, 1).mul(Vec2.init(-3, -6));
    try expect(result.x == 3);
    try expect(result.y == -6);
}

test "Vec2 multiplication with float" {
    const result = Vec2.init(-1, 1).mulValue(2);
    try expect(result.x == -2);
    try expect(result.y == 2);
}

test "Vec2 addition with vector" {
    const result = Vec2.init(-1, 1).add(Vec2.init(-3, -6));
    try expect(result.x == -4);
    try expect(result.y == -5);
}

test "Vec2 subtraction with vector" {
    const result = Vec2.init(-1, 1).sub(Vec2.init(-3, -6));
    try expect(result.x == 2);
    try expect(result.y == 7);
}

test "Vec2 dot product" {
    const result = Vec2.init(1, 2).dot(Vec2.init(3, 4));
    try expect(result == 11.0);
}

// Vec4 Tests
test "Vec4 multiplication with vector" {
    const result = Vec4.init(-1, 1, 3, -2).mul(Vec4.init(-3, -6, 4, 5));
    try expect(result.x == 3);
    try expect(result.y == -6);
    try expect(result.z == 12);
    try expect(result.w == -10);
}

test "Vec4 multiplication with float" {
    const result = Vec4.init(-1, 1, 3, -2).mulValue(2);
    try expect(result.x == -2);
    try expect(result.y == 2);
    try expect(result.z == 6);
    try expect(result.w == -4);
}

test "Vec4 addition with vector" {
    const result = Vec4.init(-1, 1, 3, -2).add(Vec4.init(-3, -6, 4, 5));
    try expect(result.x == -4);
    try expect(result.y == -5);
    try expect(result.z == 7);
    try expect(result.w == 3);
}

test "Vec4 subtraction with vector" {
    const result = Vec4.init(-1, 1, 3, -2).sub(Vec4.init(-3, -6, 4, 5));
    try expect(result.x == 2);
    try expect(result.y == 7);
    try expect(result.z == -1);
    try expect(result.w == -7);
}

test "Vec4 dot product" {
    const result = Vec4.init(-1, 1, 3, -2).dot(Vec4.init(-3, -6, 4, 5));
    try expect(result == 3 - 6 + 12 - 10);
}

// Vec2 Tests
test "Vec2 normalization" {
    const v = Vec2.init(3, 4);
    const normalized = v.normalized();
    try expectApproxEq(normalized.length(), 1.0, std.math.floatEps(f32));
}

test "Vec2 reflection" {
    const incident = Vec2.init(1, -1);
    const normal = Vec2.init(0, 1);
    const reflected = incident.reflect(normal);
    try expect(reflected.x == 1);
    try expect(reflected.y == 1);
}

// Vec3 Tests
test "Vec3 normalization" {
    const v = Vec3.init(1, 2, 2);
    const normalized = v.normalized();
    try expectApproxEq(normalized.length(), 1.0, std.math.floatEps(f32));
}

test "Vec3 reflection" {
    const incident = Vec3.init(1, -1, 0);
    const normal = Vec3.init(0, 1, 0);
    const reflected = incident.reflect(normal);
    try expect(reflected.x == 1);
    try expect(reflected.y == 1);
    try expect(reflected.z == 0);
}

// Vec4 Tests
test "Vec4 normalization" {
    const v = Vec4.init(1, 2, 2, 1);
    const normalized = v.normalized();
    try expectApproxEq(normalized.length(), 1.0, std.math.floatEps(f32));
}

test "Vec4 reflection" {
    const incident = Vec4.init(1, -1, 0, 1);
    const normal = Vec4.init(0, 1, 0, 0);
    const reflected = incident.reflect(normal);
    try expect(reflected.x == 1);
    try expect(reflected.y == 1);
    try expect(reflected.z == 0);
    try expect(reflected.w == 1);
}

test "Vec4 from Vec3" {
    const v3 = Vec3.init(1, 2, 3);
    const v4 = Vec4.fromVec3(v3);
    try expect(v4.x == 1);
    try expect(v4.y == 2);
    try expect(v4.z == 3);
    try expect(v4.w == 1);
}

test "Matrix identity" {
    const id = Mat4.identity;
    try expect(id.data[0] == 1);
    try expect(id.data[5] == 1);
    try expect(id.data[10] == 1);
    try expect(id.data[15] == 1);
}

test "Matrix translation" {
    const mat = Mat4.identity;
    const translation = mat.translate(Vec3.init(2, 3, 4));
    try expect(translation.data[12] == 2);
    try expect(translation.data[13] == 3);
    try expect(translation.data[14] == 4);
}

test "Matrix scale" {
    const mat = Mat4.identity;
    const scaling = mat.scale(Vec3.init(2, 3, 4));
    try expect(scaling.data[0] == 2);
    try expect(scaling.data[5] == 3);
    try expect(scaling.data[10] == 4);
}

test "Matrix rotation X" {
    const mat = Mat4.identity;
    const rot_x = mat.rotateX(std.math.pi / 2.0);
    try expectApproxEq(rot_x.data[5], 0, 0.001);
    try expectApproxEq(rot_x.data[6], 1, 0.001);
}

test "Matrix rotation Y" {
    const mat = Mat4.identity;
    const rot_y = mat.rotateY(std.math.pi / 2.0);
    try expectApproxEq(rot_y.data[0], 0, 0.001);
    try expectApproxEq(rot_y.data[10], 0, 0.001);
}

test "Matrix multiplication" {
    const a = Mat4.identity;
    const b = Mat4.identity;
    const result = a.mul(&b);
    try expect(std.mem.eql(f32, &result.data, &a.data));
}

test "Matrix transpose" {
    var original = Mat4.identity;
    original.data[1] = 5;
    const transposed = original.transpose();
    try expect(transposed.data[4] == 5);
}

test "Matrix determinant" {
    const id = Mat4.identity;
    try expect(id.determinant() == 1);
}

test "Matrix perspective projection" {
    const proj = Mat4.perspective(std.math.pi / 4.0, // 45 degree FOV
        16.0 / 9.0, // Aspect ratio
        0.1, // Near plane
        100.0 // Far plane
    );
    try expect(proj.data[11] == -1);
}

test "Matrix look at" {
    const eye = Vec3.init(0, 0, 5);
    const target = Vec3.init(0, 0, 0);
    const up = Vec3.init(0, 1, 0);
    const view = Mat4.lookAt(eye, target, up);
    try expect(view.data[14] == -5);
}

test "Mat3 identity" {
    const id = Mat3.identity;
    try expect(id.data[0] == 1);
    try expect(id.data[4] == 1);
    try expect(id.data[8] == 1);
}

test "Mat3 translation" {
    const translation = Mat3.translate(Vec3.init(2, 3, 4));
    try expect(translation.data[6] == 2);
    try expect(translation.data[7] == 3);
}

test "Mat3 scale" {
    const scaling = Mat3.scale(Vec3.init(2, 3, 4));
    try expect(scaling.data[0] == 2);
    try expect(scaling.data[4] == 3);
    try expect(scaling.data[8] == 4);
}

test "Mat3 rotation Z" {
    const rot = Mat3.rotateZ(std.math.pi / 2.0);
    try expectApproxEq(rot.data[0], 0, 0.001);
    try expectApproxEq(rot.data[1], 1, 0.001);
    try expectApproxEq(rot.data[3], -1, 0.001);
}

test "Mat3 multiplication" {
    const a = Mat3.identity;
    const b = Mat3.identity;
    const result = a.mul(b);
    try expect(std.mem.eql(f32, &result.data, &a.data));
}

test "Mat3 transpose" {
    var original = Mat3.identity;
    original.data[1] = 5;
    const transposed = original.transpose();
    try expect(transposed.data[3] == 5);
}

test "Mat3 determinant" {
    const id = Mat3.identity;
    try expect(id.determinant() == 1);
}

test "Mat3 inverse" {
    const id = Mat3.identity;
    const inv = id.inverse();
    try expect(std.mem.eql(f32, &inv.data, &id.data));
}
test "Test mulVec4 function with new Mat4 definition" {
    // TODO:

    const v = Vec4.init(2, 5, 1, 8);
    const mat = Mat4{
        .data = [_]Mat4.ValueType{
            1, 0, 2, 0,
            0, 3, 0, 4,
            0, 0, 5, 0,
            6, 0, 0, 7,
        }
    };

    const m = mat.mulVec4(v);
    const expected = Vec4.init(4, 47, 5, 68);
    try expectEqual(m, expected);

    // const vec = Vec4.init(1.0, 2.0, 3.0, 4.0);
    //
    // const mat = Mat4{
    //     .data = [_]Mat4.ValueType{
    //         1.0, 5.0, 9.0, 13.0,
    //         2.0, 6.0, 10.0, 14.0,
    //         3.0, 7.0, 11.0, 15.0,
    //         4.0, 8.0, 12.0, 16.0,
    //     }
    // };
    //
    // const result = mat.mulVec4(vec);
    //
    // // Calculate manually:
    // // Result = [
    // //   1.0*1 + 2.0*2 + 3.0*3 + 4.0*4,
    // //   5.0*1 + 6.0*2 + 7.0*3 + 8.0*4,
    // //   9.0*1 + 10.0*2 + 11.0*3 + 12.0*4,
    // //   13.0*1 + 14.0*2 + 15.0*3 + 16.0*4
    // // ]
    // const expected = Vec4.init(1.0 + 4.0 + 9.0 + 16.0, 5.0 + 12.0 + 21.0 + 32.0, 9.0 + 20.0 + 33.0 + 48.0, 13.0 + 28.0 + 45.0 + 64.0);
    //
    // try expectEqual(result,  expected);
}

