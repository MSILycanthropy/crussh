use magnus::{Error, Module as _, Object as _, RString, Ruby, function};
use poly1305::{Poly1305, Tag, universal_hash::KeyInit};
use subtle::ConstantTimeEq as _;

const KEY_SIZE: usize = 32;
const TAG_SIZE: usize = 16;

fn poly1305_auth(ruby: &Ruby, key: RString, message: RString) -> Result<RString, Error> {
    // SAFETY: We're only reading the bytes, not holding references across Ruby calls
    let key_bytes = unsafe { key.as_slice() };
    let msg_bytes = unsafe { message.as_slice() };

    if key_bytes.len() != KEY_SIZE {
        return Err(Error::new(
            ruby.exception_arg_error(),
            format!("key must be {} bytes, got {}", KEY_SIZE, key_bytes.len()),
        ));
    }

    let key_array: [u8; KEY_SIZE] = key_bytes.try_into().expect("length already checked");

    let poly = Poly1305::new(&key_array.into());
    let expected: Tag = poly.compute_unpadded(msg_bytes);

    Ok(ruby.str_from_slice(expected.as_slice()))
}

fn poly1305_verify(
    ruby: &Ruby,
    key: RString,
    tag: RString,
    message: RString,
) -> Result<bool, Error> {
    // SAFETY: We're only reading the bytes, not holding references across Ruby calls
    let key_bytes = unsafe { key.as_slice() };
    let tag_bytes = unsafe { tag.as_slice() };
    let msg_bytes = unsafe { message.as_slice() };

    if key_bytes.len() != KEY_SIZE {
        return Err(Error::new(
            ruby.exception_arg_error(),
            format!("key must be {} bytes, got {}", KEY_SIZE, key_bytes.len()),
        ));
    }

    if tag_bytes.len() != TAG_SIZE {
        return Err(Error::new(
            ruby.exception_arg_error(),
            format!("tag must be {} bytes, got {}", TAG_SIZE, tag_bytes.len()),
        ));
    }

    let key_array: [u8; KEY_SIZE] = key_bytes.try_into().expect("length already checked");

    let poly = Poly1305::new(&key_array.into());
    let expected: Tag = poly.compute_unpadded(msg_bytes);

    let is_valid: bool = expected.ct_eq(tag_bytes).into();
    Ok(is_valid)
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let crussh = ruby.define_module("Crussh")?;
    let crypto = crussh.define_module("Crypto")?;
    let poly1305 = crypto.define_module("Poly1305")?;

    poly1305.define_singleton_method("auth", function!(poly1305_auth, 2))?;
    poly1305.define_singleton_method("verify", function!(poly1305_verify, 3))?;

    poly1305.const_set("KEY_SIZE", KEY_SIZE)?;
    poly1305.const_set("TAG_SIZE", TAG_SIZE)?;

    Ok(())
}
