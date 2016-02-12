import 'dapple/test.sol';
import 'gov/easy_multisig.sol';

contract helper is Debug {
    uint public _arg;
    uint public _value;
    function doSomething(uint arg) {
        _arg = arg;
        _value = msg.value;
    }
}

contract DSEasyMultisigTest1 is Test, DSEasyMultisigEvents
    DSEasyMultisig ms;
    helper h;
    function setUp() {
        ms = new DSEasyMultisig(1, 1, 1 hours);
        ms.addMember(address(this));
        h = new helper();
        helper(ms).doSomething(1);
    }
    function testFailTooFewConfirms() {
        var action = ms.easyPropose(address(h), 0, 0);
        ms.trigger(action);
    }
    function testFailNotEnoughGas() {
        var action = ms.easyPropose(address(h), 0, 1);
        ms.confirm(action);
        ms.trigger(action);
        var (a, b, result, c) = ms.getActionStatus(action);
        log_named_bool("action_result:", result);
    }
    function testFailNotEnoughValue() {
        address(0x0).send(this.balance);
        var action = ms.easyPropose(address(h), 1, 0);
        ms.confirm(action);
        ms.trigger(action);
    }
}

contract DSEasyMultisigTest is Test, DSEasyMultisigEvents
{
    Tester T1; address t1;
    Tester T2; address t2;
    DSEasyMultisig ms;
    bytes calldata;
    function setUp() {
        ms = new DSEasyMultisig(2, 3, 3 days); // 2-of-3 and 3 days for voting.
        T1 = new Tester(); t1 = address(T1);
        T2 = new Tester(); t2 = address(T2);
        T1._target( ms );
        T2._target( ms );
        ms.addMember( t1 );
        ms.addMember( t2 );
        ms.addMember( this ); // makes EasyPropose easier.
    }
    function testSetup() {
        assertTrue( ms.isMember(address(this)) );
        assertTrue( ms.isMember( t1 ), "t1 should be member" );
        assertTrue( ms.isMember( t2 ), "t2 should be member" );
        assertFalse( ms.isMember( address(0x1) ), "shouldn't be member" );
        var (r, m, e, n) = ms.getInfo();
        assertTrue(r == 2, "wrong required signatures");
        assertTrue(m == 3, "wrong member count");
        assertTrue(e == 3 days, "wrong expiration");
        assertTrue(n == 0, "wrong last action");
    }
    function testMemberAddedEvent() {
        var newMs = new DSEasyMultisig(2, 3, 3 days);
        expectEventsExact(newMs);
        MemberAdded(this);
        newMs.addMember(this);
    }
    function testFailTooManyMembers() {
        ms.addMember( address(0x1) );
    }
    function testEasyPropose() {
        expectEventsExact(ms);
        Proposed(1);
        Confirmed(1, this);
        Confirmed(1, t1);
        Triggered(1, true);

        var h = new helper();
        helper(ms).doSomething(1);
        ms.easyPropose( address(h), 0, 0 );
        assertEq( h._arg(), 0, "call shouldn't have succeeded" );
        var (r, m, e, id) = ms.getInfo();
        assertEq( id, 1, "wrong last action id");
        uint c; bool t; bool res;
        (c, e, t, res) = ms.getActionStatus(1);
        assertTrue( c == 0, "wrong number of confirmations" );
        ms.confirm(1);
        DSEasyMultisig(t1).confirm(1);
        (c, e, t, res) = ms.getActionStatus(1);
        assertTrue( c == 2, "wrong number of confirmations" );
        DSEasyMultisig(t1).trigger(1);
        assertEq( h._arg(), 1, "wrong last arg" );
        assertEq( h._value(), 0, "wrong last value" );
    }
}
