import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Support Lexora · 捐款支持",
  description: "Support Lexora's independent development and cross-platform maintenance.",
};

const qrBase = "https://raw.githubusercontent.com/xiaozhangwangxue/autoword/main/assets/donate";

export default function DonatePage() {
  return (
    <main className="donatePage">
      <nav className="nav wrap" aria-label="Donation navigation">
        <Link className="brand" href="/">
          <Image src="/lexora-icon-192.png" alt="" width={36} height={36} />
          <span>Lexora</span>
        </Link>
        <Link className="donateBack" href="/">← Back to Lexora · 返回首页</Link>
      </nav>

      <section className="donateHero wrap">
        <div className="donateHeart">♥</div>
        <p className="sectionLabel">Support independent development · 支持独立开发</p>
        <h1>Help good words<br /><em>travel further.</em></h1>
        <p>
          Lexora is free to use and built with care. Your voluntary support helps
          cover cross-platform testing, code signing, data services, and long-term maintenance.
        </p>
        <p className="donateZh">Lexora 免费使用，并由个人持续维护。你的自愿支持将用于跨平台测试、应用签名、数据服务和长期更新。</p>
      </section>

      <section className="qrGrid wrap">
        <article>
          <div className="qrHeading"><span className="wechatDot">微</span><div><h2>微信支付</h2><p>WeChat Pay</p></div></div>
          <div className="qrFrame">
            <Image src={`${qrBase}/wechat.png`} alt="微信支付收款码" width={620} height={620} unoptimized />
          </div>
          <p>打开微信扫一扫 · Scan with WeChat</p>
        </article>
        <article>
          <div className="qrHeading"><span className="alipayDot">支</span><div><h2>支付宝</h2><p>Alipay</p></div></div>
          <div className="qrFrame">
            <Image src={`${qrBase}/alipay.jpg`} alt="支付宝收款码" width={620} height={620} unoptimized />
          </div>
          <p>打开支付宝扫一扫 · Scan with Alipay</p>
        </article>
      </section>

      <section className="donateNote wrap">
        <div>
          <strong>Thank you. 谢谢你的认可。</strong>
          <p>Donations are entirely optional and do not unlock paid features. Lexora remains free to use.</p>
          <p>捐款完全自愿，不会解锁额外付费功能；Lexora 会继续保持免费使用。</p>
        </div>
        <Link href="/">Continue to Lexora →</Link>
      </section>
    </main>
  );
}
