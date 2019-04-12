module hashed.hashed_container;

import std.conv : to;
import std.format : format;
import std.json;
import std.variant : Variant;
import hashed.container;
import hashed.exceptions;

class HashedContainer(K) : Container!K {
    this() {
    }

    this(JSONValue value) {
        if(!parseJSONContent(value)) {
            throw(new HashedException("Unrecognised data format for hashed container content."));
        }        
    }

    this(string content) {
        if(!parseJSONContent(content)) {
            throw(new HashedException("Unrecognised data format for hashed container content."));
        }
    }

    this(Variant[K] entries) {
        foreach(K key, Variant value; entries) {
            Variant copy = value;
            _entries[key] = copy;
        }
    }

    V fetch(V)(K key, V alternative) {
        return(includes(key) ? get!V(key) : alternative);
    }

    V get(V)(K key) {
        if(!includes(key)) {
            throw(new HashedException(format("Unknown key '%s' specified.", key)));
        }

        return(_entries[key].get!V());
    }

    bool includes(K key) const {
        return((key in _entries) !is null);
    }

    @property K[] keys() const {
        return(_entries.keys);
    }

    Variant opIndex(K index) {
        if(index !in _entries) {
            throw(new HashedException("Invalid index for hashed container."));
        }
        return(_entries[index]);
    }

    void opIndexAssign(T)(T value, K index) {
        Variant actual = value;
        _entries[index] = actual;
    }

    @property ulong length() const {
        return(_entries.length);
    }

    void set(V)(K key, V value) {
        Variant entry = Variant(value);
        _entries[key] = entry;
    }

    JSONValue toJSON() const {
        JSONValue root = parseJSON("{}");

        foreach(K key, Variant value; _entries) {
            root[to!string(key)] = variantToJSONValue(value);
        }

        return(root);
    }

    override string toString() const {
        string output = "{";

        foreach(K key, Variant value; _entries) {
            if(output != "{") {
                output ~= ",\n ";
            }
            output ~= format("%s = %s", key, value);
        }
        output ~= "}";

        return(output);
    }

    private bool parseJSONContent(string content) {
        try {
            return(parseJSONContent(parseJSON(content)));
        } catch(Exception exception) {
            return(false);
        }
    }

    private bool parseJSONContent(JSONValue root) {
        try {
            if(root.type == JSONType.object) {
                Variant[string] entries = parseJSONObject(root);

                foreach(string key, Variant value; entries) {
                    _entries[to!K(key)] = value;
                }
            }
        } catch(Exception exception) {
            return(false);
        }

        return(true);
    }

    private Variant[] parseJSONArray(JSONValue value) const {
        Variant[] entries;

        foreach(JSONValue entry; value.array) {
            entries ~= JSONValueToVariant(entry);
        }

        return(entries);
    }

    private Variant[string] parseJSONObject(JSONValue object) const {
        Variant[string] entries;

        foreach(string key, JSONValue value; object) {
            entries[key] = JSONValueToVariant(value);
        }

        return(entries);
    }

    private Variant JSONValueToVariant(JSONValue value) const {
        Variant output;

        switch(value.type) {
            case JSONType.string:
                output = value.str();
                break;

            case JSONType.integer:
                output = value.integer();
                break;

            case JSONType.uinteger:
                output = value.uinteger;
                break;

            case JSONType.float_:
                output = value.floating;
                break;

            case JSONType.array:
                output = parseJSONArray(value);
                break;

            case JSONType.object:
                output = new HashedContainer!string(parseJSONObject(value));
                break;

            case JSONType.true_:
                output = true;
                break;

            case JSONType.false_:
                output = false;
                break;

            default:
                break;
        }

        return(output);
    }

    private JSONValue variantToJSONValue(Variant value) const {
        JSONValue output;
        auto type = value.type;

        if(type == typeid(int) || type == typeid(long) || type == typeid(short)) {
            output = JSONValue(value.get!long());
        } else if(type == typeid(uint) || type == typeid(ulong) || type == typeid(ushort)) {
            output = JSONValue(value.get!ulong());
        } else if(type == typeid(float) || type == typeid(double)) {
            output = JSONValue(value.get!double());
        } else if(type == typeid(bool)) {
            output = JSONValue(value.get!bool());
        } else if(type == typeid(HashedContainer!K)) {
            output = containerToJSONValue(value.get!(HashedContainer!K)());
        } else if(type == typeid(Variant[])) {
            output = arrayToJSONValue((value.get!(Variant[])()));
        } else if(!value.hasValue) {
            output = JSONValue(null);
        } else if(type == typeid(string)) {
            output = JSONValue(value.get!string());
        } else {
            throw(new HashedException(format("Unable to convert '%s' to a JSON value.", type)));
        }

        return(output);
    }

    private JSONValue containerToJSONValue(HashedContainer!K container) const {
        JSONValue object = parseJSON("{}");

        foreach(K index; container.keys) {
            object[to!string(index)] = variantToJSONValue(container[index]);
        }

        return(object);
    }

    private JSONValue arrayToJSONValue(Variant[] array) const {
        JSONValue object = parseJSON("[]");

        for(auto i = 0; i < array.length; i++) {
            object[i] = variantToJSONValue(array[i]);
        }

        return(object);
    }

    private Variant[K] _entries;
}

//==============================================================================
// Unit Tests
//==============================================================================
unittest {
    import std.algorithm : canFind, sort;
    import std.exception;
    import std.stdio;
    import fluent.asserts;

    writeln("Running the unit tests for the HashedContainer class.");

    //--------------------------------------------------------------------------
    // this()
    //--------------------------------------------------------------------------
    auto container = new HashedContainer!(string)();
    container.length.should.equal(0);
    container.includes("non-existent").should.equal(false);

    //--------------------------------------------------------------------------
    // this(Variant[string])
    //--------------------------------------------------------------------------
    Variant[string] list;
    list["first"]  = 1;
    list["second"] = "two";
    list["third"]  = 3.14;
    container      = new HashedContainer!string(list);
    container.length.should.equal(3);
    container.includes("first").should.equal(true);
    container.includes("second").should.equal(true);
    container.includes("third").should.equal(true);
    container.includes("fourth").should.equal(false);
    container.get!int("first").should.equal(1);
    container.get!string("second").should.equal("two");
    container.get!double("third").should.equal(3.14);

    //--------------------------------------------------------------------------
    // this(string)
    //--------------------------------------------------------------------------
    auto json = "{\"first\": 1, \"second\": \"two\", \"third\": 3.14}";
    container = new HashedContainer!string(json);
    container.length.should.equal(3);
    container.includes("first").should.equal(true);
    container.includes("second").should.equal(true);
    container.includes("third").should.equal(true);
    container.includes("fourth").should.equal(false);
    container.get!long("first").should.equal(1);
    container.get!string("second").should.equal("two");
    container.get!double("third").should.equal(3.14);

    //--------------------------------------------------------------------------
    // set(K, V) & get(K)
    //--------------------------------------------------------------------------
    container.set!int("number", 1234);
    container.get!int("number").should.equal(1234);

    //--------------------------------------------------------------------------
    // includes(K)
    //--------------------------------------------------------------------------
    container.includes("number").should.equal(true);
    container.includes("non-existent").should.equal(false);

    //--------------------------------------------------------------------------
    // fetch(K, V)
    //--------------------------------------------------------------------------
    container.fetch!int("number", 4321).should.equal(1234);
    container.fetch!int("other", 4321).should.equal(4321);

    //--------------------------------------------------------------------------
    // Test with alternative key type.
    //--------------------------------------------------------------------------
    auto floatKeyed = new HashedContainer!float();
    floatKeyed.set(1.0, "this");
    floatKeyed.set(1.1, "and");
    floatKeyed.set(1.2, "that");
    floatKeyed.length.should.equal(3);
    floatKeyed.includes(1.0).should.equal(true);
    floatKeyed.includes(1.1).should.equal(true);
    floatKeyed.includes(1.2).should.equal(true);
    floatKeyed.includes(2.0).should.equal(false);
    floatKeyed.get!string(1.0).should.equal("this");
    floatKeyed.get!string(1.1).should.equal("and");
    floatKeyed.get!string(1.2).should.equal("that");

    //--------------------------------------------------------------------------
    // keys()
    //--------------------------------------------------------------------------
    float[] compare = [1.0, 1.1, 1.2];

    floatKeyed.keys.sort().should.equal(compare);
    container.keys.sort().should.equal(["first", "number", "second", "third"]);

    //--------------------------------------------------------------------------
    // opIndex(K)
    //--------------------------------------------------------------------------
    floatKeyed[1.1].get!string().should.equal("and");
    container["number"].get!int().should.equal(1234);

    //--------------------------------------------------------------------------
    // opIndexAssign(K, T)
    //--------------------------------------------------------------------------
    floatKeyed[1.3] = "suffix";
    container["suffix"] = 9876;
    floatKeyed[1.3].get!string().should.equal("suffix");
    container["suffix"].get!int().should.equal(9876);

    //--------------------------------------------------------------------------
    // Test handing of contained objects.
    //--------------------------------------------------------------------------
    json = "{\"first\": {\"second\": \"two\", \"third\": 3.14}}";
    container = new HashedContainer!string(json);
    container.length.should.equal(1);
    container.includes("first").should.equal(true);
    assertNotThrown!HashedException(container.get!(HashedContainer!string)("first"));
    container = container.get!(HashedContainer!string)("first");
    container.length.should.equal(2);
    container.includes("second").should.equal(true);
    container.includes("third").should.equal(true);
    container.get!string("second").should.equal("two");
    container.get!double("third").should.equal(3.14);

    //--------------------------------------------------------------------------
    // asJSON()
    //--------------------------------------------------------------------------
    json = "{\"first\": 1, \"second\": \"two\", \"third\": 3.14}";
    container = new HashedContainer!string(json);
    auto rootJSON = container.toJSON();

    rootJSON["first"].integer.should.equal(1);
    rootJSON["second"].str.should.equal("two");
    rootJSON["third"].floating.should.equal(3.14);

    json = "{\"first\": {\"second\": \"two\", \"third\": 3.14}}";
    container = new HashedContainer!string(json);
    rootJSON = container.toJSON();

    rootJSON["first"].type.should.equal(JSONType.object);
    rootJSON = rootJSON["first"];
    rootJSON["second"].str.should.equal("two");
    rootJSON["third"].floating.should.equal(3.14);
}
