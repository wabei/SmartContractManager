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
contract WaBeiNotice {

	address owner;

	address checker;

	address costRecver;

	mapping (address => mapping (uint => Notice)) noticePool;

	mapping (address => uint[]) noticeIds;
		
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
    	address _who;
    	uint noticeId;

    }

	struct Notice{

		// dynamic gen(needn't)
		uint noticeId;
		// notice ipfs hash
		string pic;
		// notice content ipfs hash 
		string noticeContent;
		// notice Title 
		string noticeTitle;

		/** notice state 
		*	10001 : prePublish
		*	10002 : publish
		*	10003 : checked
		*/	
		uint noticeState;

		// 合约状态相应的一些描述
		string msg;

		// 公告所有人发布公告的地址
		address who;
	}

	/**
	*	publish notice with notice owner
	*	it's will store noticePool and return the noticeId
	**/
	function prePublish(string _title , string _pic, string _content, uint _expired) external returns(uint _id){
		
		Notice storage notice = new Notice();

		notice.who = msg.sender;
		notice.noticeId = block.timestamp;
		notice.pic = _pic;
		notice.noticeTitle = _title;
		notice.noticeContent = _content;
		notice.msg = 'prePublish';
		notice.noticeState = state.prePublish;
		notice._expired = block.timestamp + _expired;
		// save notice for address
		noticePool[address][notice.noticeId] = notice;
		// save noticeId with address
		noticeIds[address].push(notice.noticeId);

		return notice.noticeId;
	}

	function doPublish(uint _value, uint _id) external  returns(bool _res, string _msg){
		
		Notice storage notice = noticePool[msg.sender][_id];

		bool isExist = (bool)(notice); 
		if (!isExist) {
			return (false, 'notice is not exist');
		}

		// check from Balances 
		bool balanceCheck = (balance(msg.sender) > _value);
		if (!balanceCheck) {
			return (false , 'publisher balance is not enough');
		}


		// check from address is legal 
		bool accountCheck = (msg.sender != costRecver);
		if (!accountCheck) {
			return (false, 'msg.sender must not costRecver');
		}

		// check the value is legal
		bool valueCheck = ((balance(costRecver) += _value)>balancesOf(costRecver));
		if (!valueCheck) {
			return (false, 'value is not legal');
		}

		balances(msg.sender) -= _value;

		balances(costRecver) += _value;

		notice.noticeState = state.publish;

		return (true, 'publish is success');

	}

	function doPublishCheck(address _who, uint _id, bool _agree, string _checkMsg) external onlyChecker  returns(bool _res,string _msg){

		Notice storage notice = noticePool[_who][_id];
		
		// check notice is exist
		bool isExist = bool(notice); 
		if (!isExist) {
			return (false, 'notice is not exist');
		}

		// check notice state is publish 
		bool isPublished = notice.state == state.publish;
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
		return (true, 'checked finish');
	}

	// admin close the publish 
	function doNoticeClose(address _who, uint _id) external onlyOwner returns(bool _res, string _msg) {
		Notice storage notice = noticePool[_who][_id];
		
		// check notice is exist
		bool isExist = (bool)(notice); 
		if (!isExist) {
			return (false, 'notice is not exist');
		}

		bool isClose = notice.state == state.closed;
		if (isClose) {
			return (false, 'notice has closed');
		}

		notice.state = state.closed;
		notice.msg = 'admin closed, contact ours';

		return (true, 'notice close success');
	}


}