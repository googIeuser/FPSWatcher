package com.fpswatcher.app

import org.json.JSONArray
import org.json.JSONObject

/**
 * Converts Android/JSON values into the limited set supported by Flutter's
 * StandardMessageCodec. In particular, org.json.JSONArray and JSONObject
 * cannot be sent through a MethodChannel directly.
 */
object FlutterChannelValue {
    fun sanitize(value: Any?): Any? {
        if (value == null || value === JSONObject.NULL) return null
        return when (value) {
            is Boolean,
            is String,
            is ByteArray,
            is IntArray,
            is LongArray,
            is DoubleArray -> value

            is Byte, is Short, is Int -> (value as Number).toInt()
            is Long -> value
            is Float, is Double -> (value as Number).toDouble()

            is JSONArray -> List(value.length()) { index ->
                sanitize(value.opt(index))
            }

            is JSONObject -> {
                val output = LinkedHashMap<String, Any?>()
                val keys = value.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    output[key] = sanitize(value.opt(key))
                }
                output
            }

            is Map<*, *> -> stringMap(value)
            is Iterable<*> -> value.map(::sanitize)
            is Array<*> -> value.map(::sanitize)
            else -> value.toString()
        }
    }

    fun stringMap(value: Map<*, *>): HashMap<String, Any?> {
        val output = HashMap<String, Any?>(value.size)
        value.forEach { (key, item) ->
            if (key != null) output[key.toString()] = sanitize(item)
        }
        return output
    }
}
