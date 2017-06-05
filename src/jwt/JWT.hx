package jwt;

import haxe.Json;
import haxe.crypto.Base64;
import haxe.crypto.Hmac;
import haxe.io.Bytes;

/**
 *  The result of a call to JWT.verify.
 *  If the token is valid and the signatures match, it contains the payload.
 */
enum JWTResult<T> {
    Valid(payload:T);
    Invalid;
}

class JWT {
    private function new(){}

    private static function signature(alg:JWTAlgorithm, body:String, secret:String):Bytes {
        if(alg != JWTAlgorithm.HS256) throw "HS256 is the only supported algorithm for now!";

        var hmac:Hmac = new Hmac(HashMethod.SHA256);
        var sb:Bytes = hmac.make(Bytes.ofString(secret), Bytes.ofString(body));
        return sb;
    }

    /**
     *  Creates a signed JWT
     *  @param header - header information. If null, will default to HS256 encryption
     *  @param payload - The data to include
     *  @param secret - The secret to generate the signature with
     *  @return String
     */
    public static function sign<T>(payload:T, secret:String, ?header:JWTHeader):String {
        if(header == null) {
            header = {
                alg: JWTAlgorithm.HS256,
                typ: JWTType.JWT
            };
        }

        // for now
        header.alg = JWTAlgorithm.HS256;

        var h:String = Json.stringify(header);
        var p:String = Json.stringify(payload);
        var hb64:String = Base64.encode(Bytes.ofString(h));
        var pb64:String = Base64.encode(Bytes.ofString(p));
        var sb:Bytes = switch(header.alg) {
            case JWTAlgorithm.HS256: signature(header.alg, hb64 + "." + pb64, secret);
            default: throw 'The ${cast(header.alg)} algorithm isn\'t supported yet!';
        }
        var s:String = Base64.encode(sb);

        return hb64 + "." + pb64 + "." + s;
    }

    // TODO: add @:generic when https://github.com/HaxeFoundation/haxe/issues/3697 is sorted

    /**
     *  Verifies a JWT and returns the payload if successful
     *  @param jwt - the token to examine
     *  @param secret - the secret to compare it with
     *  @return JWTResult<T>
     */
    public static function verify<T>(jwt:String, secret:String):JWTResult<T> {
        var parts:Array<String> = jwt.split(".");
        if(parts.length != 3) return JWTResult.Invalid;

        var h:String = Base64.decode(parts[0]).toString();
        var header:JWTHeader = cast(Json.parse(h));
        if(header.alg != JWTAlgorithm.HS256) throw 'The ${cast(header.alg)} algorithm isn\'t supported yet!';

        var p:String = Base64.decode(parts[1]).toString();

        // verify the signatures match!
        var sb:Bytes = Base64.decode(parts[2]);
        var testSig:Bytes = signature(header.alg, parts[0] + "." + parts[1], secret);
        if(sb.compare(testSig) != 0) return JWTResult.Invalid;

        // TODO: validate public claims (iss, sub, exp, etc)

        return JWTResult.Valid(Json.parse(p));
    }
}