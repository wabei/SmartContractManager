pragma solidity ^0.4.18;

/**
*	公告合约
*	
*	1 设置合约收款地址
*	2 合约可以上传并保存图片+文字对应的ipfs信息
*	3 合约设置转账地址，相同账户完成转账后，我们将之前的合约内容设置为等待审核
*	4 Dapp抓取等待审核的合约给审核方，审核方审核通过后予以放行
*	5 Dapp和官网动态抓取审核通过的公告，并做相应的展示
*	
*/
library SafeMath {
    function sub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        assert(c >= a);
        return c;
    }

    function mul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        
        assert(b!=0);
        
        uint256 c = a / b;
        return c;
    }
}

contract WaBeiNotice {
    
    using SafeMath for uint;

	address owner;

	address checker;

	address costReciver;

	mapping (address => mapping (uint => Notice)) noticePool;

	mapping (address => uint[]) noticeIds;

	mapping (uint => NoticePublish) publishNotices;
	
	uint currentIndex;

	modifier onlyOwner() { 
        require(msg.sender == owner);
        _;
    }

    modifier onlyChecker() {
    	require(msg.sender == checker);
    	_;
    }

    enum state{ prePublish, publish, checked, checkFail, expired, closed}

    struct NoticePublish{
    	bool valid;
    	address who;
    	uint noticeId;

    }

	struct Notice{

		uint index;
		// dynamic gen(needn't)
		uint noticeId;
		// notice ipfs hash
		string pic;
		// notice content ipfs hash 
		string noticeContent;
		// notice Title 
		string noticeTitle;
        bool isRegisted;
        
        uint expired;

		/** notice state 
		*	10001 : prePublish
		*	10002 : publish
		*	10003 : checked
		*/	
		state noticeState;

		// 合约状态相应的一些描述
		string msg;

		// 公告所有人发布公告的地址
		address who;
	}
	
	event LogPublishNotice(uint indexed index,  address _who, uint _id);
	
	constructor(address _checker, address _costReciver) public {
	    owner = msg.sender;
	    
	    require(msg.sender != _checker && msg.sender != _costReciver);
	    
	    costReciver = _costReciver;
	    checker = _checker;
	}
	

	/**
	*	publish notice with notice owner
	*	it's will store noticePool and return the noticeId
	**/
	function prePublish(string _title , string _pic, string _content, uint _expired) external returns(uint _id){
		
        Notice storage notice = noticePool[msg.sender][now];
		notice.isRegisted = true;
		notice.who = msg.sender;
		notice.noticeId = now;
		notice.pic = _pic;
		notice.noticeTitle = _title;
		notice.noticeContent = _content;
		notice.msg = 'prePublish';
		notice.noticeState = state.prePublish;
		notice.expired = now + _expired;

		// save noticeId with address
		noticeIds[msg.sender].push(notice.noticeId);

		return notice.noticeId;
	}

	function doPublish(uint _value, uint _id) payable public returns(bool _res, string _msg){
		
		Notice storage notice = noticePool[msg.sender][_id];
    
        require(notice.isRegisted);

		// check from Balances 
		bool balanceCheck = (msg.sender.balance > _value);
		if (!balanceCheck) {
			return (false , 'publisher balance is not enough');
		}


		// check from address is legal 
		bool accountCheck = (msg.sender != costReciver);
		if (!accountCheck) {
			return (false, 'msg.sender must not costRecver');
		}

		// check the value is legal
		bool valueCheck = ((costReciver.balance.add(_value)) > costReciver.balance);
		if (!valueCheck) {
			return (false, 'value is not legal');
		}

		costReciver.transfer(_value);

		notice.noticeState = state.publish;

		return (true, 'publish is success');

	}

	function doPublishCheck(address _who, uint _id, bool _agree, string _checkMsg) external onlyChecker  returns(bool _res,string _msg){

		Notice storage notice = noticePool[_who][_id];
		
		// check notice is exist
		if(!notice.isRegisted) {
		    return (false, 'notice is not exist');
		}

		// check notice state is publish 
		bool isPublished = (notice.noticeState == state.publish);
		if (!isPublished) {
			return (false, 'notice is not puhlish ');
		}

		if (_agree) {
			notice.noticeState = state.checked;	
			notice.msg = 'checked finsh';
		} else {
			notice.noticeState = state.checkFail;
			notice.msg = _checkMsg;
		}

		uint index = currentIndex++;

		notice.index = index;

		publishNotices[index].valid = true;
		publishNotices[index].who = notice.who;
		publishNotices[index].noticeId = notice.noticeId;

		return (true, 'checked finish');
	}

	// admin close the publish 
	function doNoticeClose(address _who, uint _id) external onlyOwner returns(bool _res, string _msg) {
		Notice storage notice = noticePool[_who][_id];
		
		// check notice is exist
		if (notice.isRegisted) {
		    return (false, 'notice is not exist');
		}

		bool isClose = notice.noticeState == state.closed;
		if (isClose) {
			return (false, 'notice has closed');
		}

		notice.noticeState = state.closed;
		notice.msg = 'admin closed, contact ours';

		return (true, 'notice close success');
	}

    function getCurrnetNoticeIndex() public view returns(uint _currentindex) {
        return currentIndex;
    }

	function getNoticeList() public {
		for (uint i=0; i < currentIndex; i++ ){
			if(publishNotices[i].valid) {
				emit LogPublishNotice(i, publishNotices[i].who, publishNotices[i].noticeId);
			}
		}
	}

	function getPublicState(address _who, uint _id) public view returns(string _title, string _pic, state s, uint expired,uint publishIndex) {
		return (noticePool[_who][_id].noticeTitle,  noticePool[_who][_id].pic, noticePool[_who][_id].noticeState, noticePool[_who][_id].expired, noticePool[_who][_id].index);
	}


}